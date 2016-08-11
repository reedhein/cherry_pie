require 'pry'
require 'awesome_print'
require 'active_support/time'
require_relative './lib/tools'
require_relative '../global_utils/global_utils'
ActiveSupport::TimeZone[-8]
RubyZoho::Crm::Lead.include Inspector
RubyZoho::Crm::Lead.send :inspector, :id
RubyZoho::Crm::Account.include Inspector
RubyZoho::Crm::Account.send :inspector, :id
DB::SalesForceProgressRecord.include Inspector
class CherryPie
  include Utils
  attr_reader :sf_client
  def initialize(limit: nil, project: 'ultra_migration', id: nil, environment: 'production', offset: 0)
    # hold_process until past_midnight?
    @id               = id
    @limit            = limit
    @offset           = offset
    Utils.environment = @environment = environment
    Utils.limiter     = 0.06
    @sf_client        = Utils::SalesForce::Client.instance
    @box_client       = Utils::Box::Client.instance
    @do_work          = true
    @fields           = get_fields('Case')
    @meta             = DB::Meta.first_or_create(project: project)
    @offset_date      = Utils::SalesForce.format_time_to_soql(@meta.offset_date)
  end

  def process_work_queue(work_queue: :get_unfinished_objects, process_tools: [ZohoNoteMigration, AttachmentMigrationManager])
    begin
      @total = 0
      while @do_work == true do
        @do_work = false
        @processed = 0
        @repeat_blocker = []

        self.send(work_queue) do |sf|
          break if repeat?(sf)
          process_tools.each do |tool|
            tool.new(sf, @meta).perform
          end
          @offset_date = sf.created_date # creates a marker for next query
          @meta.offset_date = @offset_date
          @meta.save
          @meta.updated_count += 1
          @processed += 1
          @total     += 1
          puts "^"*88
          puts "Processed: #{@processed}"
          puts "Total: #{@total}"
          puts "^"*88
          @do_work    = true
        end
      end

    rescue Net::OpenTimeout, SocketError, Errno::ETIMEDOUT, Faraday::ConnectionFailed => e
      puts "error " * 10
      puts e.to_s
      puts "error " * 10
      sleep 3
      retry
    rescue RuntimeError => e
      if e.to_s =~ /4820/
        hold_process until past_midnight? || two_hour_interlude?
        retry
      end
    rescue => e
      puts e.backtrace
      binding.pry
    ensure
      @meta.offset_date = @offset_date
      @meta.save
    end
  end

  private

  def get_fields(sf_object_name)
    fields = ['Utils', 'SalesForce', sf_object_name, 'FIELDS'].join('::').constantize
    convert_fields(fields)
  end

  def convert_fields(fields)
    fields.map do |x|
      if x =~ /__/
        x
      else
        x.camelize
      end
    end.join(', ')
  end

  def repeat?(sf)
    if @repeat_blocker.include? sf.id
      puts "%"*88
      puts "found a duplicate workload id: #{sf.id}"
      puts "%"*88
      @do_work = false
      true
    else
      @repeat_blocker << sf.id
      false
    end
  end

  def populate_csv(sf, csv)
    value_array = []
    value_array << Nokogiri::HTML(sf.body).text.squish.encode('ISO-8859-1', invalid: :replace, undef: :replace, replace: '?')
    value_array << sf.created_date
    value_array << sf.case.case_id_18__c
    value_array << sf.case.status
    value_array << sf.case.is_closed
    value_array << sf.case.exit_completed_date__c
    puts '*' * 88
    puts value_array
    puts '*' * 88
    csv << value_array
  end

  def exit_complete
    begin
      @total = 0
      while @do_work == true do
        @do_work = false
        @processed = 0
        CSV.open('funtimes', 'a+', headers: true , encoding: 'ISO-8859-1') do |csv|
          headers = ['FeedItemBody', 'FeedItemCreatedDate', 'CaseId(18)', 'CaseStatus', 'CaseIsClosed', 'CaseExitCompletedDate']
          csv << headers if csv.header_row?
          map = []
          get_unfinished_exit_objects do |sf|
            @offset_date = sf.created_date # creates a marker for next query
            if sf.body =~ /Exit Complete/i || sf.title =~ /Exit Complete/i
              populate_csv(sf, csv)
            end
            binding.pry if map.include? sf.id
            map << sf.id
            @processed += 1
            @total     += 1
            puts "^"*88
            puts "Processed: #{@processed}"
            puts "Total: #{@total}"
            puts "^"*88
            @do_work    = true
          end
        end
      end
    rescue Net::OpenTimeout, SocketError, Errno::ETIMEDOUT, Faraday::ConnectionFailed
      sleep 5
      retry
    rescue => e
      ap e
      binding.pry
    ensure 
      @meta.update(offset_date: @offset_date)
    end
  end

  def get_unfinished_objects(&block)
    if @id
      query = "SELECT #{@fields} FROM Opportunity WHERE id = '#{@id}'"
    elsif @offset_date
      query = "SELECT #{@fields} FROM Opportunity WHERE Zoho_ID__c LIKE 'zcrm%' AND CreatedDate < #{@offset_date} ORDER BY CreatedDate DESC"
    else
      query = "SELECT #{@fields} FROM Opportunity WHERE Zoho_ID__c LIKE 'zcrm%'  ORDER BY CreatedDate DESC"
    end
    query << " LIMIT #{@limit}" if @limit
    @sf_client.custom_query(query: query) do |sushi|
      yield sushi if block_given?
    end
  end

  def get_unfinished_case_objects(&block)
    if @id
      query = "SELECT #{@fields} FROM Opportunity WHERE id = '#{@id}'"
    elsif @offset_date
      query = 
        <<-EOF
          SELECT #{@fields},
          (SELECT Id, createdById, Name, Description FROM Attachments),
          (SELECT id, createddate, CreatedById, type, body, title FROM feeds)
          FROM Case
          WHERE Zoho_ID__c LIKE 'zcrm_%'
          AND CreatedDate > #{@offset_date}
          ORDER BY CreatedDate ASC
        EOF
    else
      query =
        <<-EOF
          SELECT #{@fields},
          (SELECT Id, createdById, Name, Description FROM Attachments),
          (SELECT id, createddate, CreatedById, type, body, title FROM feeds)
          FROM Case
          WHERE Zoho_ID__c LIKE 'zcrm_%'
          ORDER BY CreatedDate ASC
        EOF
    end
    query << " LIMIT #{@limit}" if @limit
    @sf_client.custom_query(query: query) do |sushi|
      yield sushi if block_given?
    end

  end

  def get_unfinished_exit_objects(&block)
    if @offset_date
      puts "&"*88
      puts @offset_date
      puts "&"*88
      query= "select id, title, createddate, body, parentid from feeditem where type in ('TextPost', 'LinkPost', 'ContentPost', 'CaseCommentPost', 'CallLogPost', 'AdvancedTextPost') and parentid in (select id from case) AND CreatedDate > #{@offset_date} ORDER BY CreatedDate ASC LIMIT 3000"
    else
      query= "select id, title, createddate, body, parentid from feeditem where type in ('TextPost', 'LinkPost', 'ContentPost', 'CaseCommentPost', 'CallLogPost', 'AdvancedTextPost') and parentid in (select id from case) ORDER BY CreatedDate ASC LIMIT 3000"
    end
    @sf_client.custom_query(query: query) do |sushi|
      yield sushi if block_given?
    end
  end

  def get_possible_zoho_dupes
    if @id 
      query = "SELECT #{@fields} FROM Opportunity WHERE id = '#{@id}'"
    elsif @offset_date
      puts "#"*88
      puts "offset date: #{@offset_date}"
      puts "#"*88
      query = 
        <<-EOF
          SELECT #{@fields},
          (SELECT id, createddate, body, title from notes),
          (SELECT Id, createdById, Name, Size, Description FROM Attachments),
          (SELECT id, createddate, CreatedById, type, body, title FROM feeds)
          FROM Opportunity
          WHERE Zoho_ID__c != Null
          AND (NOT Zoho_ID__c LIKE 'zcrm_%')
          AND CreatedDate > #{@offset_date}
          ORDER BY CreatedDate ASC
        EOF
    else
      query = "SELECT #{@fields} FROM Opportunity WHERE Zoho_ID__c != Null AND (NOT Zoho_ID__c LIKE 'zcrm_%') ORDER BY CreatedDate ASC"
    end
    query << " LIMIT #{@limit}" if @limit
    # query << " OFFSET #{@offset}" if @offset
    @sf_client.custom_query(query: query) do |sushi|
      yield sushi if block_given?
    end
  end

end


CherryPie.new(project: 'cas_dup_auditor', limit: 5 ).process_work_queue(work_queue: :get_unfinished_case_objects, process_tools: [ZohoSalesForceAttachmentMigration]) 
# CherryPie.new(id: '00661000005R3M1AAK', project: 'dup_auditor').process_work_queue(work_queue: :get_possible_zoho_dupes, process_tools: [AttachmentMigrationTool])
# CherryPie.new().exit_complete()
puts 'fun times!'


require 'pry'
require 'active_support/time'
require_relative './lib/contact_note_to_case'
require_relative './lib/attachment_migration_tool'
require_relative './lib/bring_forward_zoho'
require_relative '../global_utils/global_utilities'
# RubyZoho::Crm::Contact.include Inspector
# RubyZoho::Crm::Contact.send :inspector, :id
# RubyZoho::Crm::Potential.include Inspector
# RubyZoho::Crm::Potential.send :inspector, :id, :account_name, :description
ActiveSupport::TimeZone[-8]
RubyZoho::Crm::Lead.include Inspector
RubyZoho::Crm::Lead.send :inspector, :id
RubyZoho::Crm::Account.include Inspector
RubyZoho::Crm::Account.send :inspector, :id
DB::SalesForceProgressRecord.include Inspector
class CherryPie
  attr_reader :sf_client
  def initialize(limit: 2000, project: :migration, id: nil, environment: 'production')
    @id           = id
    @environment  = environment
    $environment  = environment
    Utils::Box.environment = environment
    # @limit        = limit
    @offset_date  = nil
    @sf_client    = Utils::SalesForce::Client.instance
    @box_client    = Utils::Box::Client.instance
    @do_work      = true
    @fields       = get_opportunity_fields
    @meta         = DB::Meta.first_or_create(project: project)
  end

  def process_work_queue(tools = nil)
    process_tools = tools || [ContactNoteToCase]
    begin
      @total = 0
      while @do_work == true do
        @do_work = false
        @processed = 0
        get_sales_force_work_queue do |sf|
          if sf.notes_migration_complete?
            puts sf.id
            puts "already processed"
          else
            process_tools.each do |tool|
              tool.new(sf, @meta).perform
            end
            # sf.mark_all_completed
            @meta.updated_count += 1
          end
          @processed += 1
          puts "Processed: #{@processed}"
          @total     += 1
          puts "Total: #{@total}"
          @do_work    = true
        end
      end
    rescue Net::OpenTimeout, SocketError, Errno::ETIMEDOUT, Faraday::ConnectionFailed
      sleep 5
      retry
    rescue RuntimeError => e
      if e =~ /4820/
        binding.pry
      end
    rescue => e
      binding.pry
    end
  end

  def exit_complete
    begin
      @total = 0
      while @do_work == true do
        @do_work = false
        @processed = 0
        CSV.open('funtimes', 'w', headers: true , encoding: 'ISO-8859-1') do |csv|
          headers = ['FeedItemBody', 'FeedItemCreatedDate', 'CaseId(18)', 'CaseStatus', 'CaseIsClosed', 'CaseExitCompletedDate']
          csv << headers
          map = []
          get_unfinished_exit_objects do |sf|
            @offset_date = sf.created_date
            if sf.body =~ /Exit Complete/i || sf.title =~ /Exit Complete/i }
              populate_csv(sf, csv)
            end
            binding.pry if map.include? sf.id
            map << sf.id
            @processed += 1
            puts "Processed: #{@processed}"
            @total     += 1
            puts "Total: #{@total}"
            @do_work    = true
          end
        end
      end
    rescue Net::OpenTimeout, SocketError, Errno::ETIMEDOUT, Faraday::ConnectionFailed
      sleep 5
      retry
    rescue => e
      puts e
      binding.pry
    end
  end


  private

  def populate_csv(sf, csv)
    value_array = []
    value_array << Nokogiri::HTML(sf.body).text.squish
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

  def get_sales_force_work_queue(&block)
    time = DB::SalesForceProgressRecord.first(notes_migration_complete: false).try(:created_date).try(:to_s)
    @offset_date ||= Utils::SalesForce.format_time_to_soql(time) if time
    get_unfinished_objects do |record|
      if block_given?
        yield record
      else
        record
      end
    end
  end

  def get_unfinished_objects(override_query, &block)
    if @id
      query = "SELECT #{@fields} FROM Opportunity WHERE id = '#{@id}'"
    elsif @offset_date && !@offset_date.empty?
      query = "SELECT #{@fields} FROM Opportunity WHERE Zoho_ID__c LIKE 'zcrm%' AND CreatedDate <= #{@offset_date} ORDER BY CreatedDate DESC"
    else
      query = "SELECT #{@fields} FROM Opportunity WHERE Zoho_ID__c LIKE 'zcrm%'  ORDER BY CreatedDate DESC"
    end
    query << " WHERE NOT in #{@finished_ids}" if @finished_ids
    query << " LIMIT #{@limit}"               if @limit
    query << " OFFSET #{@offset}"             if @offset
    query = override_query if override_query
    @sf_client.custom_query(query: query) do |sushi|
      yield sushi if block_given?
    end
  end

  def get_unfinished_exit_objects(&block)
    if @offset_date
      query= "select id, title, createddate, body, parentid from feeditem where type in ('TextPost', 'LinkPost', 'ContentPost', 'CaseCommentPost', 'CallLogPost', 'AdvancedTextPost') and parentid in (select id from case) AND CreatedDate <= #{@offset_date} LIMIT 2000")
    else
      query= "select id, title, createddate, body, parentid from feeditem where type in ('TextPost', 'LinkPost', 'ContentPost', 'CaseCommentPost', 'CallLogPost', 'AdvancedTextPost') and parentid in (select id from case) AND CreatedDate <= #{@offset_date} LIMIT 2000") do |sf|
    end
    @sf_client.custom_query(query: query) do |sushi|
      yield sushi if block_given?
    end
  end

  def get_opportunity_fields
    Utils::SalesForce::Opportunity::FIELDS.map do |x|
      if x =~ /__/
        x
      else
        x.camelize
      end
    end.join(', ')
  end
end


@today = Date.today.day
@tomorrow = Date.tomorrow.beginning_of_day
# hold_process while work_hours?
def past_midnight?
  Time.now.to_i > @tomorrow.to_i
end

def work_hours?
    puts "work hours = #{17 < Time.now.hour && Time.now.hour > 9}"
    17 < Time.now.hour && Time.now.hour > 9
end

def hold_process
  seconds_left = @tomorrow.to_i - Time.now.to_i
  puts "#{seconds_left} seconds until zoho api limits reset"
  sleep 60
end
binding.pry
#hold_process until past_midnight?

# CherryPie.new().process_work_queue()
CherryPie.new().exit_complete()
puts 'fun times!'


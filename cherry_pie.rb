require 'pry'
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
  attr_reader :sf_client
  def initialize(limit: nil, project: 'ultra_migration', id: nil, environment: 'production', offset: 0)
    @id               = id
    @limit            = limit
    @offset           = offset
    Utils.environment = @environment = environment
    @sf_client        = Utils::SalesForce::Client.instance
    @box_client       = Utils::Box::Client.instance
    @do_work          = true
    @fields           = get_opportunity_fields
    @meta             = DB::Meta.first_or_create(project: project)
    @offset_date      = nil #@meta.offset_date
  end

  def process_work_queue(work_queue: :get_unfinished_objects, process_tools: [NoteMigrationManager])
    begin
      @total = 0
      while @do_work == true do
        @do_work = false
        @processed = 0
        self.public_send(work_queue) do |sf|
          @offset_date = sf.created_date # creates a marker for next query
          process_tools.each do |tool|
            tool.new(sf, @meta).perform
          end
          @meta.updated_count += 1
          @processed += 1
          puts "Processed: #{@processed}"
          @total     += 1
          puts "Total: #{@total}"
          @do_work    = true
        end
        binding.pry if @do_work == false
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
    ensure
      @meta.offset_date = @offset_date
      @meta.save
    end
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
      query = "SELECT #{@fields} FROM Opportunity WHERE = '#{@id}'"
    elsif @offset_date
      puts "#"*88
      puts "offset date: #{@offset_date}"
      puts "#"*88
      query = "SELECT #{@fields} FROM Opportunity WHERE Zoho_ID__c != Null AND (NOT Zoho_ID__c LIKE 'zcrm%')  AND CreatedDate > #{@offset_date} ORDER BY CreatedDate ASC"
    else
      query = "SELECT #{@fields} FROM Opportunity WHERE Zoho_ID__c != Null AND (NOT Zoho_ID__c LIKE 'zcrm%') ORDER BY CreatedDate ASC"
    end
    query << " LIMIT #{@limit}" if @limit
    query << " OFFSET #{@offset}" if @offset
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


private

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

CherryPie.new().process_work_queue(work_queue: :get_possible_zoho_dupes, process_tools: [DupeAuditor])
# CherryPie.new().exit_complete()
puts 'fun times!'


class DupeAuditor
  # used to figure out all the salesforce records that have a zoho_id__c populated
  # but the data is not accurate.  some 16k records are affected by this
  def initialize(sf, meta)
    puts "1"*88
    puts "Dup checking for #{sf.id}"
    puts "1"*88
    @sf = sf
    @meta = meta
  end

  def perform
    find_result = @sf.find_zoho
    if find_result.nil?
      in_depth_search
    else
      binding.pry
      @sf.update({zoho_id__c: nil})
    end
  end

  def in_depth_search
    find_result = Utils::SalesForce::Determine.new(@sf).find_zoho
    zoho_results = [find_result.contacts, find_result.leads, find_result.potentials, find_result.accounts].flatten
    if zoho_results.count == 1
      @sf.zoho_id__c = "zcrm_#{zoho_results.first.id}"
      NoteMigrationManager.new(@sf, @meta).perform
      AttachmentMigrationTool.new(@sf, @meta).perform
      @sf.update({zoho_id__c: "zcrm_#{zoho_results.first.id}"})
    else
      puts 'more than one association'
      binding.pry
    end
  end

end

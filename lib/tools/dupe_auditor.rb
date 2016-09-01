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
    find_result = @sf.find_zoho #unless @sf.zoho_id__c =~ /^zcrm_/
    if find_result.nil? && @sf.zoho_id__c != nil
      in_depth_search
    else
      puts 'Sales order migration bullshit'
      # @sf.update({zoho_id__c: nil}) unless @sf.zoho_id__c.nil?
    end
  end

  def in_depth_search
    find_result = Utils::SalesForce::Determine.new(@sf).find_zoho
    zoho_results = [find_result.contacts, find_result.leads, find_result.potentials, find_result.accounts].flatten
    if zoho_results.count == 1 #currently only returning the first positive hit, this will always be true
      @sf.zoho_id__c = "zcrm_#{zoho_results.first.id}"
      NoteMigrationManager.new(@sf, @meta).perform
      ZohoSalesForceAttachmentMigration.new(@sf, @meta).perform
      @sf.update({zoho_id__c: "zcrm_#{zoho_results.first.id}"})
    elsif zoho_results.count == 0
      puts "can't find this record in zoho"
    else
      binding.pry
      puts 'more than one association'
    end
  end

end

class DupeAuditor
  # used to figure out all the salesforce records that have a zoho_id__c populated
  # but the data is not accurate.  some 16k records are affected by this
  def initialize(sf, meta)
    @sf = sf
    @meta = meta
  end

  def perform
    if Utils::SalseForce::Determine.new(@sf).detect_zoho
      in_depth_search
    else
      @sf.update({zoho_id__c: nil})
    end
  end

  def in_depth_search
    Utils::SalseForce::Determine.new(@sf).find_zoho
    zoho_results = [find_result.contacts, find_result.leads, find_result.potentials, find_result.accounts].flatten
    if zoho_results.count == 1
      binding.pry
      @sf.update({zoho_id__c: zoho_results.first.id})
    else
      puts 'more than one association'
      binding.pry
    end
  end

end

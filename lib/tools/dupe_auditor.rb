class DupeAuditor
  def initialize(sf, meta)
    @sf = sf
    @meta = meta
  end

  def perform
    find_result = @sf.find_zoho
    if find_result.contacts.empty? && find_result.leads.empty? && find_result.potentials.empty? && find_result.accounts.empty?
      puts '*'*88
      puts "removing zoho reference for: #{@sf.id}"
      puts '*'*88
      @sf.update({zoho_id__c: nil})
    end
  end
end

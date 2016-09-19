class IdTagger
  def initialize(sf, meta)
    puts "id"*44
    puts "marking id for zoho migrated record"
    puts "id"*44
    @sf = sf
    @meat = meta
  end

  def perform
    find_result = @sf.find_zoho #unless @sf.zoho_id__c =~ /^zcrm_/
    if find_result
      puts '0'*88
      puts 'found zoho record: do nothing'
      puts find_result.inspect
      puts '0'*88
      return
    else
      find_result = Utils::SalesForce::Determine.new(@sf).find_zoho
      zoho_results = [find_result.contacts, find_result.leads, find_result.potentials, find_result.accounts].flatten
      if zoho_results.count == 1 #currently only returning the first positive hit, this will always be true
        puts "*"*88
        puts "updating"
        puts "*"*88
        @sf.update({zoho_id__c: "zcrm_#{zoho_results.first.id}"})
      elsif zoho_results.count == 0
        puts '7'*88
        puts "can't find this record in zoho"
        puts '7'*88
      else
        binding.pry
        puts 'more than one association'
      end
    end
    sleep 1
  end
end

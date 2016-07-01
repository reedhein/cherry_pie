class AttachmentMigrationTool
  def initialize(sf, meta)
    puts "5" * 88
    puts "Processing attachments for #{sf.type}: #{sf.id}"
    puts "5" * 88
    @meta = meta
    @sf   = sf
  end

  def perform
    if @sf.is_a? Utils::SalesForce::Opportunity
      process_opportunities
    else
      ZohoSalesForceAttachmentMigration.new(@sf, @meta).perform
    end
  end

  private

  def process_opportunities
    ZohoSalesForceAttachmentMigration.new(@sf, @meta).perform #populates @sf.cases as side effect
    @sf.cases.each do |sf_case|
      ZohoSalesForceAttachmentMigration.new(sf_case, @meta).perform
    end
    @sf.contacts do |sf_contact|
      ZohoSalesForceAttachmentMigration.new(sf_contact, @meta).peform
    end
  end
end

class SalesForceBoxAttachmentMigration
  def initialize(sf, meta)
    @meta = meta
    @sf   = sf
  end

  def perform
    prove_or_instantiate_box_connection
    wait_for_box_connection
    binding.pry
  end

  private 

  def wait_for_box_connection
    while @sf.client.query("SELECT iD FROM Box__FRUP__c where Record_ID__c = #{@sf.id}").empty?
      sleep 2
    end
  end

  def prove_or_instantiate_box_connection
    @sf.update(Create_Box_Folder__c: true) if @sf.create_box_folder == false && (@sf.type == "Case" || @sf.type == 'Opportunity')
  end
end


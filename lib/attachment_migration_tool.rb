class AttachmentMigrationTool
  def initialize(sf, meta)
    @meta = meta
    @sf   = sf
  end

  def perform
    if sf.zoho_id__c =~ /^zcrm_/
      ZohoSalesForceAttachmentMigration.new(sf, meta).perform
      SalesForceBoxAttachmentMigration.new(sf, meta).perform
    else
      SalesForceBoxAttachmentMigration.new(sf, meta).perform
    end
  end
end

class ZohoSalesForceAttachmentMigration
  attr_accessor :meta
  def initialize(sf, meta)
    @meta        = meta
    @sf          = sf
    @zoho        = sf.find_zoho
  end


  def perform
    return if @zoho.is_a? Utils::SalesForce::Determine
    zoho_attachments = @zoho.attachments
    sf_attachment_names   = @sf.attachments.entries.map{|attachment| attachment.fetch('Name')}
    zoho_attachments.map do |za|
      @sf.zoho_attach(@zoho, za) if sf_attachment_names.include? zoho_attachment[:file_name]
    end
    if @sf.modified?
      @meta.updated_count += 1
      @meta.save
    end
    @zoho.mark_migration_complete(:attachment)
    @sf.mark_migration_complete(:attachment)
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


class AttachmentMigrationTool
  def initialize(sf, meta)
    @meta = meta
    @sf   = sf
  end

  def perform
    if sf_file.is_a? String #return value from a migration and Restforce::Client.create
      #NOOP keep going
    else
      @sf.box_attach(@zoho, attachment)
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
    return if @zoho.is_a?(Utils::SalesForce::Determine) || @zoho.is_a?(VirtualProxy)
    attachments = @zoho.attachments
    attachments.map do |attachment|
      sf_file = @sf.zoho_attach(@zoho, attachment)
    end
    if @sf.modified?
      @meta.updated_count += 1
      @meta.save
    end
    @zoho.mark_migration_complete(:attachment)
    @sf.mark_migration_complete(:attachment)
  end
end

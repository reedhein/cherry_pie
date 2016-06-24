class AttachmentMigrationTool
  attr_accessor :meta
  def initialize(sf, meta)
    @meta        = meta
    @sf          = sf
    @zoho        = sf.find_zoho
  end

  def perform
    return if @zoho.is_a?(Utils::SalesForce::Determine) || @zoho.is_a?(VirtualPoxy)
    attachments = @zoho.attachments
    attachments.map do |attachment|
      @sf.attach(@zoho, attachment)
    end
    if @sf.modified?
      @meta.updated_count += 1
      @meta.save
    end
    @zoho.mark_migration_complete(:attachment)
    @sf.mark_migration_complete(:attachment)
  end
end

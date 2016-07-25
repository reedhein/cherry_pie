class ZohoSalesForceAttachmentMigration
  attr_accessor :sf, :meta
  def initialize(sf, meta)
    @meta        = meta
    @sf          = sf
    @zoho        = sf.find_zoho
  end


  def perform
    # @zoho_equivilant = @sf.find_zoho
    # if @zoho_equivilant.nil?
    #   DupeAuditor.new(@sf, @meta).perform
    #   return
    # end
    sf_attachments      = @sf.attachments || []
    zoho_attachments    = @zoho.attachments
    sf_attachment_names = sf_attachments.map{|attachment| attachment.name}
    zoho_attachments.map do |za|
      @sf.zoho_attach(@zoho, za) if !sf_attachment_names.include? za.file_name
    end
    if @sf.modified?
      @meta.updated_count += 1
      @meta.save
    end
    @zoho.mark_migration_complete(:attachment)
    @sf.mark_migration_complete(:attachment)
  end
end

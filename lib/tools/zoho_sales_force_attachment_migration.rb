class ZohoSalesForceAttachmentMigration
  attr_accessor :sf, :meta
  def initialize(sf, meta)
    @meta        = meta
    @sf          = sf
    @zoho        = sf.find_zoho
  end


  def perform
    @zoho_equivilant = @sf.find_zoho
    if @zoho_equivilant.nil?
      DupeAuditor.new(@sf, @meta).perform 
      return
    end
    zoho_attachments = @zoho_equivilant.attachments
    sf_attachment_names   = @sf.attachments.entries.map{|attachment| attachment.name}
    zoho_attachments.map do |za|
      @sf.zoho_attach(@zoho_equivilant, za) if !sf_attachment_names.include? zoho_attachment[:file_name]
    end
    if @sf.modified?
      @meta.updated_count += 1
      @meta.save
    end
    @zoho_equivilant.mark_migration_complete(:attachment)
    @sf.mark_migration_complete(:attachment)
  end
end

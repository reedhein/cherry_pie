class ZohoSalesForceAttachmentMigration
  attr_accessor :sf, :meta
  def initialize(sf, meta)
    @meta        = meta
    @sf          = sf
    @zoho        = sf.find_zoho
  end


  def perform
    if @zoho.nil?
      # DupeAuditor.new(@sf, @meta).perform
      return
    end
    return if @sf.migration_complete?(:attachment)
    sf_attachments      = @sf.attachments || []
    zoho_attachments    = @zoho.attachments
    sf_attachment_names = sf_attachments.map{|attachment| attachment.name }
    binding.pry if sf.id == "50061000001ly3IAAQ"
    zoho_attachments.each do |za|
      puts "looking for: #{za.file_name}"
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

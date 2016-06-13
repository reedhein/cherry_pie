class AttachmentMigrationTool
  attr_accessor :meta
  def initialize(zoho_sushi, sales_force_sushi, meta)
    @meta              = meta
    @zoho_sushi        = zoho_sushi
    @sales_force_sushi = sales_force_sushi
  end

  def perform
    attachments = @zoho_sushi.attachments
    attachments.map do |attachment|
      @sales_force_sushi.attach(@zoho_sushi, attachment)
    end
    updated_count = @meta.updated_count += 1
    if @sales_force_sushi.modified?
      @meta.updated_count += 1
      @meta.save
    end
    @zoho_sushi.mark_completed
    @sales_force_sushi.mark_completed
  end
end

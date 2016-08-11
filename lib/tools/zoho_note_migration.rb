class ZohoNoteMigration
  attr_reader :meta, :sf
  def initialize(sf, meta)
    puts "2" * 88
    puts "Processing notes for #{sf.type}: #{sf.id}"
    puts "2" * 88
    @meta = meta
    @sf   = sf #written to be potentials
  end

  def perform
    @zoho_equivilant = @sf.find_zoho
    if @zoho_equivilant.nil?
      DupeAuditor.new(@sf, @meta).perform
      return
    end
    @chatters  = @sf.chatters
    puts "#{@sf.type} id: #{@sf.id}"

    uniq_notes(@sf).each_with_index do |note, i|
      puts "#{i + 1} #{note.module_name} to #{@sf.type}"
      Utils::SalesForce::FeedItem.create_from_zoho_note(note, @sf)
      note.mark_migration_complete(:note)
    end
    @sf.mark_migration_complete(:notes)
  end

  private

  def uniq_notes(sf_object)
    all_the_notes.delete_if do |n|
      puts "testing note: #{n.note_content}"
      n.note_migration_complete? ||
      (n.note_content.empty? && n.title.empty?) ||
      note_already_migrated?(n)
    end
  end

  def all_the_notes
    @zoho_equivilant.try(:notes) || []
  end

  def note_already_migrated?(note)
    @chatters.detect do |c|
      note1 = note.note_content.squish
      note2 = Nokogiri::HTML(c.body).text.gsub('::FROM ZOHO::', '').gsub(/AUTHORED BY \(.+\)/, '').squish
      note1 == note2 && Date.parse(note.created_time) == Date.parse(c.created_date)
    end
  end
end

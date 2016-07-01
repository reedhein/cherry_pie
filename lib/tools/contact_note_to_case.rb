class ZohoCaseNoteMigration
  attr_reader :meta, :sf
  def initialize(sf, meta)
    @meta = meta
    @sf   = sf #written to be Case
  end

  def perform
    @zoho_equivilant = @sf.find_zoho
    return if @zoho_equivilant.is_a? Utils::SalesForce::Determine
    @chatters  = @sf.chatters
    puts @sf.id

    uniq_notes.each_with_index do |note, i|
      puts "#{i + 1} potential to opportunity"
      Utils::SalesForce::FeedItem.create_from_zoho_note(note, @sf)
      note.mark_migration_complete(:note)
    end
    @sf.mark_migration_complete(:notes)
  end

  private

  def uniq_notes
    all_the_notes.delete_if do |n|
      # n.note_migration_complete? ||
      n.note_content.empty? ||
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
        note1 == note2
      end
  end
end

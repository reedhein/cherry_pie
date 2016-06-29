class ZohoContactNoteMigration
  attr_reader :meta, :sf
  def initialize(sf, meta)
    @meta = meta
    @sf   = sf #a salesforce Case object
  end

  def perform
    @contact = @sf.find_zoho
    return if @contact.is_a?(Utils::SalesForce::Determine) || @contact.is_a?(VirtualProxy)
    @chatters  = @sf.chatters
    @contact   = @potential.contacts.first #where the notes live
    puts @sf.id
    uniq_notes.each_with_index do |note, i|
      #stick potential notes onto opportunity
      puts "#{i + 1} potential to opportunity"
      Utils::SalesForce::FeedItem.create_from_zoho_note(note, @sf)
      note.mark_migration_complete(:note)
    end
    @sf.mark_migration_complete(:notes)
  end

  private 

  def uniq_notes
    notes = @contact.try(:notes) || []
    notes.delete_if do |n|
      n.note_migration_complete? ||
      n.note_content.empty? ||
      note_already_migrated?(n)
    end
  end

  def note_already_migrated?(note)
    @chatters.detect do |c|
      note1 = note.note_content.squish
      note2 = Nokogiri::HTML(c.body).text.gsub('::FROM ZOHO::', '').gsub(/AUTHORED BY \(.+\)/, '').squish
      note1 == note2
    end
  end
end

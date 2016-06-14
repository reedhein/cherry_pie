class ContactNoteToCase
  attr_reader :meta, :sf
  def initialize(sf, meta)
    @meta = meta
    @sf   = sf #written to be potentials
  end

  def perform
    @potential = @sf.find_zoho
    @case      = @sf.cases.first
    @chatters  = @sf.chatters
    @contact   = @potential.contacts.first
    @notes     = @contact.nil? ? @potential.notes : @contact.notes
    puts "processing: #{uniq_notes.count} notes"
    count = uniq_notes.count
    puts @sf.id
    uniq_notes.each_with_index do |note, i|
      puts "#{i + 1} of #{count}"
      Utils::SalesForce::FeedItem.create_from_zoho_note(note, @sf)
      note.mark_migration_complete(:note)
    end
    if @case && @sf.cases.count == 1
      uniq_notes(@case.chatters).each_with_index do |note, i|
        puts "#{i + 1} of #{count} for case"
        Utils::SalesForce::FeedItem.create_from_zoho_note(note, @case)
        note.mark_migration_complete(:note)
      end
    end
    @case.try(:mark_migration_complete,:notes)
    @sf.mark_migration_complete(:notes)
  end

  def uniq_notes(chatters = @chatters)
    @uniq_notes ||= @notes.delete_if do |n|
      n.note_migration_complete? || n.note_content.empty? ||
        chatters.detect do |c|
          note1 = n.note_content.squish
          note2 = Nokogiri::HTML(c.body).text.gsub('::FROM ZOHO::', '').gsub(/AUTHORED BY \(.+\)/, '').squish
          note1 == note2
        end
    end
  end
end

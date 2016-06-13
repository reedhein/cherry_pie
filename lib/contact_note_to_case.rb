class ContactNoteToCase
  attr_reader :meta, :sf
  def initialize(sf, meta)
    @meta = meta
    @sf   = sf #written to be potentials
  end

  def perform
    @potential = @sf.find_zoho
    @case      = @sf.cases.first
    @chatters  = @sf.chatters || @case.try(:chatters)
    @contact   = @potential.contacts.first
    @notes     = @contact.notes
    puts "processing: #{uniq_notes.count} notes"
    count = @uniq_notes.count
    puts @sf.id
    @uniq_notes.each_with_index do |note, i|
      puts "#{i + 1} of #{count}"
      Utils::SalesForce::FeedItem.create_from_zoho_note(note, @sf)
      Utils::SalesForce::FeedItem.create_from_zoho_note(note, @case) if @case && @sf.cases.count == 1
      note.mark_migration_complete(:note)
    end
    @case.try(:mark_migration_complete,:notes)
    @sf.mark_migration_complete(:notes)
  end

  def uniq_notes
    @uniq_notes ||= @notes.delete_if do |n|
      # n.note_migration_complete? ||
        @chatters.detect do |c|
          n.note_content.squish == Nokogiri::HTML(c.body).text.gsub('::FROM ZOHO::', '').gsub(/AUTHORED BY \(.+\)/, '').squish
        end
    end
  end
end

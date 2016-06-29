class ZohoPotentialNoteMigration
  attr_reader :meta, :sf
  def initialize(sf, meta)
    @meta = meta
    @sf   = sf #written to be potentials
  end

  def perform
    @potential = @sf.find_zoho
    return if @potential.is_a?(Utils::SalesForce::Determine) || @potential.is_a?(VirtualProxy)
    @cases     = @sf.cases
    @chatters  = @sf.chatters
    @contact   = @potential.contacts.first
    puts @sf.id

    uniq_notes.each_with_index do |note, i|
      #stick potential notes onto opportunity
      puts "#{i + 1} potential to opportunity"
      Utils::SalesForce::FeedItem.create_from_zoho_note(note, @sf)
      note.mark_migration_complete(:note)
    end
    @case.mark_migration_complete(:notes) if @case
    @sf.mark_migration_complete(:notes)
  end

  private

  def uniq_notes
    all_the_notes.delete_if do |n|
      n.note_migration_complete? ||
      n.note_content.empty? ||
      note_already_migrated?(n)
    end
  end

  def all_the_notes
    notes = []
    (@potential.try(:notes) || []).each do |n|
      notes << n
    end
    if @cases.empty? #the lead (sale) probably unseccussful
      (@contact.try(:notes) || []).each do |n|
        notes << n
      end
    end
    notes
  end

  def note_already_migrated?(note)
      @chatters.detect do |c|
        note1 = note.note_content.squish
        note2 = Nokogiri::HTML(c.body).text.gsub('::FROM ZOHO::', '').gsub(/AUTHORED BY \(.+\)/, '').squish
        note1 == note2
      end
  end
end

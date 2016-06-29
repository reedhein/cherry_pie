class ZohoPotentialNoteMigration
  attr_reader :meta, :sf
  def initialize(sf, meta)
    @meta = meta
    @sf   = sf #written to be potentials
  end

  def perform
    @potential = @sf.find_zoho
    return if @potential.is_a? Utils::SalesForce::Determine
    @case      = @sf.cases.first
    @chatters  = @sf.chatters
    @contact   = @potential.contacts.first
    puts @sf.id
    if @case && @sf.cases.count == 1
      puts 'stick contact notes onto case'
      uniq_notes(@case).each_with_index do |note, i|
        puts "#{i + 1} contact notes on case"
        Utils::SalesForce::FeedItem.create_from_zoho_note(note, @case)
        note.mark_migration_complete(:note)
      end
    end

    if @case.nil? && @contact && @contact.notes.present?
      puts 'stick contacts notes directly on opportuntiy' if uniq_notes(@case).present?
      uniq_notes(@case).each_with_index do |note, i|
        puts "#{i + 1} putting contact notes onto opportunity"
        Utils::SalesForce::FeedItem.create_from_zoho_note(note, @sf)
      end
    end

    uniq_notes(@sf).each_with_index do |note, i|
      #stick potential notes onto opportunity
      puts "#{i + 1} potential to opportunity"
      Utils::SalesForce::FeedItem.create_from_zoho_note(note, @sf)
      note.mark_migration_complete(:note)
    end
    @case.mark_migration_complete(:notes) if @case
    @sf.mark_migration_complete(:notes)
  end

  def uniq_notes(sf_object)
    return [] unless sf_object
    case sf_object.type
    when "Opportunity"
      notes = @potential.try(:notes) || []
    when "Case"
      notes = @contact.try(:notes) || []
    end
    notes.delete_if do |n|
      n.note_migration_complete? ||
      n.note_content.empty? ||
      sf_object.chatters.detect do |c|
        note1 = n.note_content.squish
        note2 = Nokogiri::HTML(c.body).text.gsub('::FROM ZOHO::', '').gsub(/AUTHORED BY \(.+\)/, '').squish
        note1 == note2
      end
    end
  end
end

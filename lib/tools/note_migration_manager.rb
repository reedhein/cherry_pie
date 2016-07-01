class NoteMigrationManager
  attr_reader :meta, :sf, :cases
  def initialize(sf, meta)
    @meta = meta
    @sf   = sf #written to be potentials
  end

  def perform
    if @sf.is_a? Utils::SalesForce::Opportunity
      process_opportunities
    else
      ZohoNoteMigration.new(@sf, @meta).perform
    end
  end

  def process_opportunities
    ZohoNoteMigration.new(@sf, @meta).perform #populates @sf.cases as side effect
    @sf.cases.each do |sf_case|
      ZohoNoteMigration.new(sf_case, @meta).perform
    end
    @sf.contacts do |sf_contact|
      ZohoNoteMigration.new(sf_contact, @meta).peform
    end
  end

  def process_contacts
  end
end

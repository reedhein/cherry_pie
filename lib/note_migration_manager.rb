class NoteMigrationManager
  attr_reader :meta, :sf, :cases
  def initialize(sf, meta)
    @meta = meta
    @sf   = sf #written to be potentials
  end

  def peform
    case @sf
    when Utils::SalesForce::Opportunity
      process_opportunities
    when Utils::SalesForce::Case
      ZohoContactNoteMigration.new(@sf, @meta).perform
    end
  end

  def process_opportunities
    OpportunityNotesToCase.new(@sf, @meta).perform #populates @sf.cases
    @sf.cases.each do |sf_case|
      ZohoContactNoteMigration.new(sf_case, @meta).perform
    end
  end
end

class BringForwardZoho
  def initialize(sf, meta)
    @sf   = sf
    @meta = meta
    zoho = sf.find_zoho
    if zoho.is_a?( GlobalUtilities::SalesForce::Determine || VirtualPoxy )
      if sf.cases.empty? && zoho.opportunities.empty?
        create_a_case
        verified = verify_data_from_zoho_objects # large method
        unless verified
          migrate_that_shit
          email_descrepancies
        end
        if is_there_a_zoho_note_that_could_determine_status_of_case?
          test_and_update_status
        end
      else
        migrate_zoho_data_to_new_case
        if is_there_a_zoho_note_that_could_determine_status_of_case?
          migrate_that_shit
          give_a_zoho_id__c_value_for_zoho_contact_and_SF_Case
        end
      end
      if sh.zoho__id_c.empty?
      end
    end
  end

  def create_a_case
    client = @sf.client
    Subject Name Status
    client.picklist_values('Case', 'status')
    client.create('Case')
  end

  def create_chatter
    client = @sf.client
    puts client
  end

  def perform
  end
end

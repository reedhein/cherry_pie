require 'pry'
require_relative '../global_utilities/global_utilities'
class CherryPie
  attr_reader :sf_client
  def initialize
    @sf_client = GlobalUtilities::SalesForce::Client.new
  end 
end

cp = CherryPie.new
puts cp
derp = cp.sf_client.custom_query(query: "select createddate, zoho_id__c, id, amount, name from opportunity where zoho_id__c like 'zcrm%' limit 300")
# parent = derp.first.get_parent
binding.pry

puts 'fun times!'

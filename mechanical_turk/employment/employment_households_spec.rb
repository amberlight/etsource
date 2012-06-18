# 

require 'spec_helper'

describe "Households, Space Heating" do

  context "for the start scenario" do
    before(:each) do 
      load_scenario(area_code: "nl", end_year: 2050)
    end
    
    # For every space heating technology, the turk_number_of_units should go to #HHs when slider = 100%
    it "turk_number_of_households_space_heater_combined_network_gas" do
      move_slider 333, 100 #%
      the_future.should be_within(7349500.0,5.0)
    end
    
    it "turk_number_of_households_space_heater_collective_heatpump_water_water_ts_electricity" do
      move_slider 375, 100 #%
      the_future.should be_within(23647.0, 10.0)
    end
    
    it "turk_number_of_households_space_heater_heatpump_ground_water_electricity" do
      move_slider 338, 100 #%
      the_future.should be_within(7349500.0, 10.0)
    end
    
    it "turk_number_of_households_space_heater_wood_pellets" do
      move_slider 340, 100 #%
      the_future.should be_within(7349500.0, 10.0)
    end

    it "turk_number_of_households_space_heater_coal" do
      move_slider 411, 100 #%
      the_future.should be_within(7349500.0, 10.0)
    end

    it "turk_number_of_households_space_heater_crude_oil" do
      move_slider 248, 100 #%
      the_future.should be_within(7349500.0, 10.0)
    end
 
    it "turk_number_of_households_space_heater_heatpump_air_water_network_gas" do
      move_slider 317, 100 #%
      the_future.should be_within(23647.0, 10.0)
    end

    it "turk_number_of_households_space_heater_micro_chp_network_gas" do
      move_slider 51, 50 #%
      the_future.should be_within(3674750, 10.0)
    end

    it "turk_number_of_households_space_heater_electricity" do
      move_slider 52, 100 #%
      the_future.should be_within(7349500.0, 10.0)
    end
    
    it "turk_number_of_households_space_heater_network_gas" do
      move_slider 441, 100 #%
      the_future.should be_within(7349500.0, 10.0)
    end
    
    # The overall employment should change with different sliders
    # it "should decrease employment when the Electric heater is pulled to max" do
    #   move_slider 52, 100 #%
    #   @scenario.dashboard_employment.should decrease
    # end
  end
end
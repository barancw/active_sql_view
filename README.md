This project sets out to create an easy way to manage SQL views directly in your Rails app.

At the time this project started there was not a SQLless way to accomplish this in Rails.  This gem let's you easily define and manage views right from an ActiveRecord model file.

This gem creates an ActiveRecord relation that you can easily plug into anything that supports ActiveRecord!

# This Section Explains The Old Implementation.  It will still work currently but you can't use the new functions for changing the view code. #

For example


    class Award < ActiveRecord::Base
     has_many :award_type_view
    end

    class AwardTypeView < ActiveRecord::Illusion
     column :award_type, :string
     column :award_id, :integer

     belongs_to :award

     view do
       Award.select{
           [awards.type.as(award_type), awards.id.as(award_id)]
       }
     end

    end


The cool thing is, is that the relations work on both directions

a = AwardTypeView.first

      SELECT "award_type_views".* FROM 
      (SELECT "awards"."type" AS award_type, "awards"."id" AS award_id FROM awards ) 
      award_type_views LIMIT 1

a.award

       SELECT "awards".* FROM "awards" WHERE "awards"."id" = 1 LIMIT 1

b = Award.first

       SELECT "awards".* FROM "awards" LIMIT 1

b.award_type_views

       SELECT "award_type_views".* FROM 
       (SELECT "awards"."type" AS award_type, "awards"."id" AS award_id FROM awards ) 
       award_type_views 
       WHERE "award_type_views"."award_id" = 1

Currently this gem depends on the SQUEEL SQL gem

For a more detailed example see: http://stackoverflow.com/questions/6900508/how-to-create-read-only-models-in-rails-with-no-backing-table


# Updated Example To Show Expanded Functions #


       class OutageView < ActiveRecord::Illusion
          belongs_to :outage
          belongs_to :plant
          belongs_to :unit
          belongs_to :state
          belongs_to :unemployment_info

          column :outage_id, :integer
          column :start_date, :date
          column :end_date, :date
          column :length, :integer
          column :plant_id, :integer
          column :plant_name, :string
          column :unit_id, :integer
          column :unit_number, :integer
          column :reactor_type, :string
          column :owner, :string
          column :city, :string
          column :state_id, :string
          column :state, :string
          column :output, :string
          column :refuel_cycle_length, :integer
          column :notes, :string
          column :unemployment_info_id, :integer
          column :max_unemployment, :integer

          def_base_object do
            Outage
          end

          def_joins do
            [ unit.plant, state.unemployment_info ]
          end

          def_selects do
            [
              (id.as outage_id),
              start_date,
              end_date,
              length,
              (plants.id.as plant_id),
              (plants.plant_name.as plant_name),
              (unit.id.as unit_id),
              (unit.unit_number.as unit_number),
              (plants.reactor_type.as reactor_type),
              (plants.owner.as owner),
              (plants.city.as city),
              (state.id.as state_id),
              (state.abbreviation.as state),
              (unit.output.as output),
              (unit.refuel_cycle_length.as refuel_cycle_length),
              notes,
              (unemployment_infos.id.as unemployment_info_id),
              (unemployment_infos.max_amount.as max_unemployment)
            ]
          end

          update_view

          def self.set_user( user )
            if !self.get_user.nil?
                @user = user

                puts @user.email

                self.column :raw_local, :string
                self.column :union_id, :integer
                self.column :raw_phone_number, :string
                self.column :extension, :string
                self.column :trade_id, :integer
                self.column :trade_name, :string
                self.column :trade_prefix, :string

                self.add_selects do
                  [
                    (unions.id.as union_id),
                    (unions.local_number.as raw_local),
                    (unions.phone_number.as raw_phone_number),
                    (unions.extension.as extension),
                    (trades.id.as trade_id),
                    (trades.name.as trade_name),
                    (trades.prefix.as trade_prefix)
                  ]
                end

                self.add_joins do
                  [ (unit.plant.services.union.trade) ]
                end

                self.add_wheres do
                  unit.plant.services.union.trade_id.eq my{@user.trade.id}
                end


                self.update_view

              self.belongs_to :union
              self.belongs_to :trade
            end
          end
        end

# Features #

You can see from the example that you can define your selects separate from your join conditions and your where conditions.
All you need to do is pass an array in a block that is correct Squeel syntax!

You can alter your view at runtime with the add_* functions.  Be sure to call update_view afterword and like magic you've got a new view.

Everything returned is an ActiveRecord Relation object.  You can all a simple .where{ col_name.eq "anything" } on any of the columns in your view just as you would with a real table!

## Update View Based On User ##
This example shows how to add conditional logic to the view based on a user.  You can add columns anyway you like during runtime.  You can even define new associations after the initial defines.  Everything still works with your active record methods!
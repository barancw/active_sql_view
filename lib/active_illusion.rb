require 'active_record'
require 'active_support/all'

module ActiveRecord
  # requires the squeel gem
  #
  # https://github.com/ernie/squeel
  # 
  # Inherit from this class to create tableless
  # models that are backed by a query.
  #
  # For example
  #
  # class Award < ActiveRecord::Base
  #   has_many :award_type_view
  # end
  #
  # class AwardTypeView < Illusion
  #   column :award_type, :string
  #   column :award_id, :integer
  #
  #   belongs_to :award
  #
  #   view
  #     select{[awards.type.as(award_type), awards.id.as(award_id)]}.from("awards")
  #   end
  # end
  #
  # The cool thing is, is that the relations work on both directions
  #
  # a = AwardTypeView.first
  #
  #   SELECT "award_type_views".* FROM 
  #   (SELECT "awards"."type" AS award_type, "awards"."id" AS award_id FROM awards ) 
  #   award_type_views LIMIT 1
  #
  # a.award
  #
  #   SELECT "awards".* FROM "awards" WHERE "awards"."id" = 1 LIMIT 1
  #
  # b = Award.first
  #
  #   SELECT "awards".* FROM "awards" LIMIT 1
  #
  # b.award_type_views
  #
  #   SELECT "award_type_views".* FROM 
  #   (SELECT "awards"."type" AS award_type, "awards"."id" AS award_id FROM awards ) 
  #   award_type_views 
  #   WHERE "award_type_views"."award_id" = 1

  # end
  class Illusion < ActiveRecord::Base
    def self.columns() 
      @columns ||= [] 
    end  

    def self.columns_hash()
      @columns_hash ||= {}
    end

    def self.find_all
      raise "please override"
    end

    class << self
      def default_scope_with_wrap
      end
    end

    def self.view
      meta = class << self;self;end
      m = yield
      table = self.to_s.underscore.pluralize
      meta.send :define_method, :default_scope do
        q = m.arel.as table
        select{}.from(q)
      end
    end

    def self.column(name, sql_type = :string, default = nil, null = true)
      column = ActiveRecord::ConnectionAdapters::Column.new(name.to_s, default, sql_type.to_s, null)

      columns << column
      columns_hash[name.to_s] = column
    end

    self.abstract_class = true

    def self.table_name
      to_s.underscore.pluralize
    end

    def readonly?
      true
    end




    def self.def_base_object
      @@base_object_procs = [ Proc.new{ yield } ]
    end

    def self.add_scope_to_base( name_as_symbol )
      @@base_object_procs.push Proc.new{ |base_object| base_object.send name_as_symbol }
    end

    def self.clear_base_scopes()
      @@base_object_procs = [ @base_object_procs.first ]
    end

    def self.def_selects(&block)
      @@selects_procs = [ Proc.new{ |base_object| base_object.select{ self.instance_eval(&block) } } ]
    end

    def self.add_selects(&block)
      @@selects_procs.push Proc.new{ |base_object| base_object.select{ self.instance_eval(&block) } }
    end

    def self.def_joins(&block)
      @@joins_procs = [ Proc.new{ |base_object| base_object.joins{ self.instance_eval(&block) } } ]
    end

    def self.add_joins(&block)
      @@joins_procs.push Proc.new{ |base_object| base_object.joins{ self.instance_eval(&block) } }
    end

    def self.def_wheres(&block)
      @@wheres_procs = [ Proc.new{ |base_object| base_object.where{ self.instance_eval(&block) } } ]
    end

    def self.add_wheres(&block)
      @@wheres_procs.push Proc.new{ |base_object| base_object.where{ self.instance_eval(&block) } }
    end

    def self.base_object_name
      self.get_base_object.to_s
    end

    def self.to_sql
      self.get_base_with_joins_selects_object.to_sql
    end

    def self.get_base_object
      @@base_object_procs.inject{ |acc, proc| proc.call acc }
    end

    def self.get_array
      (@@base_object_procs + @@joins_procs + @@selects_procs)
    end



    private

      @@base_object_procs = []
      @@selects_procs = []
      @@joins_procs = []
      @@wheres_procs = []




    def self.get_base_with_joins_selects_object
      (@@base_object_procs[1..-1] + @@joins_procs + @@selects_procs + @@wheres_procs).inject(@@base_object_procs.first.call) { |acc, proc| proc.call acc }
    end


    def self.update_view
      view do
        self.get_base_with_joins_selects_object
      end
    end

  end
end

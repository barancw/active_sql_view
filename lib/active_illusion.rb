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
    class << self
      def columns()
        @columns ||= []
      end

      def columns_hash()
        @columns_hash ||= {}
      end


      def set_default_sort( col, order )
        col = col.to_s if col.is_a?(Symbol)
        order = order.to_s if order.is_a?(Symbol)
        @default_sort_column = col
        @default_sort_order = order
      end

      def default_sort_column
        @default_sort_column
      end

      def default_sort_order
        @default_sort_order
      end


      def displayed_columns()
        @displayed_columns ||= []
      end

      def hidden_columns()
        @hidden_columns ||= []
      end

      def default_shown_columns()
        @default_shown_columns ||= []
      end


      def find_all
        raise "please override"
      end


      def default_scope_with_wrap
      end


      def view
        meta = class << self;self;end
        m = yield
        table = self.to_s.underscore.pluralize
        meta.send :define_method, :default_scope do
          q = m.arel.as table
          select{}.from(q)
        end
      end

      def column(name, sql_type = :string, default = nil, null = true)
        column = ActiveRecord::ConnectionAdapters::Column.new(name.to_s, default, sql_type.to_s, null)

        columns << column
        displayed_columns << column.name
        columns_hash[name.to_s] = column
      end

      def default_shown_column( col )
        col = col.to_s if col.is_a?(Symbol)
        default_shown_columns.push col
      end

      def hide_column( col )
        col = col.to_s if col.is_a?(Symbol)
        if !self.displayed_columns.delete( col ).nil?
          self.hidden_columns.push col
          return true
        end
        false
      end

      def show_column( col )
        col = col.to_s if col.is_a?(Symbol)
        if !self.hidden_columns.delete( col ).nil?
          self.displayed_columns.push col
          return true
        end
        false
      end

      def column_shown?( col )
        displayed_columns.include? col
      end

      def column_hidden?( col )
        displayed_columns.include? col
      end

      def toggle_column( col )
        if self.column_shown? col
          self.hide_column col
        else
          self.show_column col
        end
      end

      abstract_class = true

      def table_name
        to_s.underscore.pluralize
      end


      def def_base_object
        @@base_object_procs = [ Proc.new{ yield } ]
      end

      def add_scope_to_base( name_as_symbol )
        @@base_object_procs.push Proc.new{ |base_object| base_object.send name_as_symbol }
      end

      def set_scope_to_base( name_as_symbol )
        self.clear_base_scopes
        self.add_scope_to_base( name_as_symbol )
      end

      def clear_base_scopes()
        @@base_object_procs = [ @base_object_procs.first ]
      end

      def def_selects(&block)
        @@selects_procs = [ Proc.new{ |base_object| base_object.select{ self.instance_eval(&block) } } ]
      end

      def add_selects(&block)
        @@selects_procs.push Proc.new{ |base_object| base_object.select{ self.instance_eval(&block) } }
      end

      def def_joins(&block)
        @@joins_procs = [ Proc.new{ |base_object| base_object.joins{ self.instance_eval(&block) } } ]
      end

      def add_joins(&block)
        @@joins_procs.push Proc.new{ |base_object| base_object.joins{ self.instance_eval(&block) } }
      end

      def def_wheres(&block)
        @@wheres_procs = [ Proc.new{ |base_object| base_object.where{ self.instance_eval(&block) } } ]
      end

      def add_wheres(&block)
        @@wheres_procs.push Proc.new{ |base_object| base_object.where{ self.instance_eval(&block) } }
      end

      def base_object_name
        self.get_base_object.to_s
      end

      def to_sql
        self.get_base_with_joins_selects_object.to_sql
      end

      def get_base_object
        @@base_object_procs.inject{ |acc, proc| proc.call acc }
      end
    end



    def readonly?
      true
    end




    private

    @@base_object_procs = []
    @@selects_procs = []
    @@joins_procs = []
    @@wheres_procs = []

    class << self

      def get_base_with_joins_selects_object
        (@@base_object_procs[1..-1] + @@joins_procs + @@selects_procs + @@wheres_procs).inject(@@base_object_procs.first.call) { |acc, proc| proc.call acc }
      end


      def update_view
        view do
          self.get_base_with_joins_selects_object
        end
      end

    end

  end
end


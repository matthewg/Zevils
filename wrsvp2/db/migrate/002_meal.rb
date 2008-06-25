class Meal < ActiveRecord::Migration
  def self.up
    create_table :meals do |table|
      table.column :name, :string, :null => false
    end
  end

  def self.down
    drop_table :meals
  end
end

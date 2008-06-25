class Person < ActiveRecord::Migration
  def self.up
    create_table :people do |table|
      table.column :name, :string, :null => false
      table.column :attending, :boolean, :null => false, :default => false
      table.column :meal_id, :integer, :null => true
      table.column :group_id, :integer, :null => false
    end
  end

  def self.down
    drop_table :people
  end
end

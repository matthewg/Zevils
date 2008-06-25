class Group < ActiveRecord::Migration
  def self.up
    create_table :groups do |table|
      table.column :login, :string, :null => false
      table.column :password, :string, :null => true
      table.column :address, :string, :null => false
      table.column :admin, :boolean, :null => false, :default => false
    end
  end

  def self.down
    drop_table :groups
  end
end

class Group < ActiveRecord::Base
  validates_presence_of :login
  validates_presence_of :address
  has_many :people, :order => "name"
end

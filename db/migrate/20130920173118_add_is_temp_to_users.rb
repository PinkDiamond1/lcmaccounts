class AddIsTempToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :is_temp, :boolean, default: true
  end
end

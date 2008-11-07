class <%= class_name %> < ActiveRecord::Migration
  # original migration was suitable only for Rails2.0, so updated to
  # work with Rails 1.2.6 as well
  
  def self.up
    create_table :activity_logs, :options => "DEFAULT CHARSET = utf8" do |t|
      t.column :action, :string
      t.column :activity_loggable_type, :string
      t.column :activity_loggable_id, :integer
      t.column :culprit_type, :string
      t.column :culprit_id, :integer
      t.column :referenced_type, :string
      t.column :referenced_id, :integer
      t.column :created_at, :datetime
      t.column :updated_at, :datetime
    end
  end

  def self.down
    drop_table :activity_logs
  end
end
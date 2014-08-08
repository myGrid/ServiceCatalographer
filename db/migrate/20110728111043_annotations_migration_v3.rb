class AnnotationsMigrationV3 < ActiveRecord::Migration
  def self.up
    
    change_table :annotations do |t|
      t.rename :value, :old_value
      t.remove :value_type
      t.string :value_type, :limit => 50, :null => false, :default => "TextValue"
      t.integer :value_id, :null => false, :default => 0
    end
    change_column :annotations, :old_value, :string, :null => true
    add_index :annotations, [ :value_type, :value_id ]
    
    change_table :annotation_versions do |t|
      t.rename :value, :old_value
      t.remove :value_type
      t.string :value_type, :limit => 50, :null => false, :default => "TextValue"
      t.integer :value_id, :null => false, :default => 0
    end
    change_column :annotation_versions, :old_value, :string, :null => true
    
    create_table :text_values, :force => true do |t|
      t.integer :version, :null => false
      t.integer :version_creator_id, :null => true
      t.text :text, :limit => 16777214, :null => false
      t.timestamps
    end
    
    create_table :text_value_versions, :force => true do |t|
      t.integer :text_value_id, :null => false
      t.integer :version, :null => false
      t.integer :version_creator_id, :null => true
      t.text :text, :limit => 16777214, :null => false
      t.timestamps
    end
    add_index :text_value_versions, [ :text_value_id ]
    
    create_table :number_values, :force => true do |t|
      t.integer :version, :null => false
      t.integer :version_creator_id, :null => true
      t.integer :number, :null => false
      t.timestamps
    end
    
    create_table :number_value_versions, :force => true do |t|
      t.integer :number_value_id, :null => false
      t.integer :version, :null => false
      t.integer :version_creator_id, :null => true
      t.integer :number, :null => false
      t.timestamps
    end
    add_index :number_value_versions, [ :number_value_id ]
    
    # ====================================
    # Additional models for the ServiceCatalogue app
    # ------------------------------------
    
    create_table :tags, :force => true do |t|
      t.string :name, :null => false
      t.string :label, :null => false
      t.timestamps
    end
    
    add_index :tags, [ :name ], :unique => true
    
    # ====================================
    
    # ================================================
    # Migrate existing annotations to the v3 db schema
    # ------------------------------------------------
    # 
    # This will use the custom migration defined in:
    # /lib/service_catalographer/annotations/custom_migration_to_v3.rb
    
    Annotation::reset_column_information
    Annotation::reload_versioned_columns_info
    Annotations::Util::migrate_annotations_to_v3
    
    # ================================================
    
    change_table :annotation_value_seeds do |t|
      t.rename :value, :old_value
      t.string :value_type, :limit => 50, :null => false, :default => "TextValue"
      t.integer :value_id, :null => false, :default => 0
    end
    change_column :annotation_value_seeds, :old_value, :string, :null => true
    
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration.new
  end
end
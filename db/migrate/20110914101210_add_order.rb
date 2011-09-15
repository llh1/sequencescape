class AddOrder < ActiveRecord::Migration
  SUBMISSION_ONLY =%w{state message}
  ORDER_ONLY = %w{study_id workflow_id user_id item_options comments project_id sti_type template_name asset_group_id asset_group_name}
  def self.rename_columns(table, columns)
    columns.each do |column|
      old_name, new_name = yield(column)
      rename_column table, old_name, new_name
    end
  end

  def self.up
    ActiveRecord::Base.transaction do
    #we copy the submission table to order table and then  remove unused columns
    connection  = ActiveRecord::Base.connection
    
    connection.execute <<-EOS
      DROP TABLE IF EXISTS orders;
    EOS
    connection.execute <<-EOS
      CREATE TABLE orders LIKE submissions;
    EOS
    add_column(:orders, :submission_id, :integer)
    connection.execute <<-EOS
      INSERT INTO orders SELECT *, id FROM submissions;
    EOS

    # we don't do it right now, as we are not changing any name
    # 
    #{:Submission => :Order ,
      #:LinearSubmission => :LinearOrder,
      #:ReRequestSubmission => :ReRequestOrder
    #}.each do |old, new|
      #conn.execute <<-EOS
          #UPDATE orders SET sti_type = '#{new}' WHERE  sti_type = '#{old}'
          #EOS
    #end

    rename_columns(:orders, SUBMISSION_ONLY) { |c| [c, "#{c}_to_delete"] }
    rename_columns(:submissions, ORDER_ONLY) { |c| [c, "#{c}_to_delete"] }

    end
  end

  def self.down
    return
    ActiveRecord::Base.transaction do
      drop_table :orders
      rename_columns(:submissions, ORDER_ONLY) { |c| ["#{c}_to_delete", c] }
    end
  end
end
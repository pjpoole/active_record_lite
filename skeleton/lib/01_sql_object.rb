require_relative 'db_connection'
require 'active_support/inflector'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    return @columns if @columns
    @columns = DBConnection.execute2(<<-SQL).first.map(&:to_sym)
      SELECT
        *
      FROM
        #{self.table_name}
    SQL
  end

  def self.finalize!
    columns.each do |column|
      define_method(column) do
        self.attributes[column]
      end

      define_method("#{column}=") do |value|
        self.attributes[column] = value
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name ||= self.name.to_s.tableize # to_s redundant? = redundant?
  end

  def self.all
    results = DBConnection.execute(<<-SQL)
      SELECT
        #{@table_name}.*
      FROM
        #{@table_name}
    SQL

    eval(self.name).parse_all(results) # eval(self.name) redundant. Why?
  end

  def self.parse_all(results)
    results.map do |result|
      self.new(result)
    end
  end

  def self.find(id)
    results = DBConnection.execute(<<-SQL, id)
      SELECT
        #{ table_name }.*
      FROM
        #{ table_name }
      WHERE
        #{ table_name }.id = ?
    SQL

    return nil if results.nil? # not necessary?

    parse_all(results).first
  end

  def initialize(params = {})
    params.each do |attr_name, value|
      attr_name = attr_name.to_sym
      raise "unknown attribute '#{attr_name}'" unless self.class.columns.include?(attr_name)
      self.send("#{attr_name}=", value)
    end
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    self.class.columns.map { |attr| self.send(attr) }
  end

  def insert
    col_names = self.class.columns.map(&:to_s).join(",")
    question_marks = (["?"] * self.class.columns.count).join(",")

    DBConnection.execute(<<-SQL, *attribute_values)
      INSERT INTO
        #{ self.class.table_name } (#{ col_names })
      VALUES
        (#{ question_marks })
    SQL

    self.id = DBConnection.last_insert_row_id
  end

  def update
    set_line = self.class.columns.map do |attr_name|
      "#{attr_name} = ?"
    end.join(", ")

    DBConnection.execute(<<-SQL, *attribute_values, id)
      UPDATE
        #{self.class.table_name}
      SET
        #{set_line}
      WHERE
        id = ?
    SQL
  end

  def save
    id.nil? ? insert : update
  end
end

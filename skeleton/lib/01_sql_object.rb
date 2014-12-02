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
    @table_name ||= self.name.to_s.tableize
  end

  def self.all
    results = DBConnection.execute(<<-SQL)
      SELECT
        #{@table_name}.*
      FROM
        #{@table_name}
    SQL

    eval(self.name).parse_all(results)
  end

  def self.parse_all(results)
    rows = []
    results.each do |result|
      rows << eval(self.name).new(result)
    end

    rows
  end

  def self.find(id)
    result = DBConnection.execute(<<-SQL, id).first
      SELECT
        #{@table_name}.*
      FROM
        #{@table_name}
      WHERE
        id = ?
    SQL

    return nil if result.nil?

    eval(self.name).new(result)
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
    self.class.columns.map { |name| self.send(name) }
  end

  def insert
    col_names = self.class.columns.drop(1).join(",")
    question_marks = (["?"] * @attributes.length).join(",")
    values = attribute_values.drop(1)

    DBConnection.execute(<<-SQL, *values)
      INSERT INTO
        #{self.class.table_name} (#{col_names})
      VALUES
        (#{question_marks})
    SQL

    self.id = DBConnection.last_insert_row_id
  end

  def update
    set_line = self.class.columns.drop(1).map do |attr_name|
      "#{attr_name} = ?"
    end.join(", ")

    DBConnection.execute(<<-SQL, *(attribute_values.drop(1)), self.id)
      UPDATE
        #{self.class.table_name}
      SET
        #{set_line}
      WHERE
        id = ?
    SQL
  end

  def save
    self.id.nil? ? insert : update
  end
end

require_relative '03_associatable'

# Phase IV
module Associatable
  # Remember to go back to 04_associatable to write ::assoc_options

  def has_one_through(name, through_name, source_name)

    define_method(name) do
      through_options = self.class.assoc_options[through_name]
      source_options =
        through_options.model_class.assoc_options[source_name]

      result = DBConnection.execute(<<-SQL, self.id)
        SELECT
          s.*
        FROM
          #{through_options.table_name} AS t
        JOIN
          #{source_options.table_name} AS s
          ON
          s.#{source_options.primary_key} = t.#{source_options.foreign_key}
        WHERE
          t.#{through_options.primary_key} = ?
      SQL

      source_options.model_class.parse_all(result).first
    end
  end
end

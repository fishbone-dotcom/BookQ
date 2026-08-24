# Assigns each appointment a column (and the total column count of its
# overlap cluster) so overlapping appointments — different staff booked at
# the same time — render side-by-side instead of stacked illegibly.
class CalendarLayout
  Placement = Struct.new(:appointment, :column, :columns, keyword_init: true)

  def initialize(appointments)
    @appointments = appointments.sort_by(&:starts_at)
  end

  def placements
    clusters.flat_map { |cluster| place_cluster(cluster) }
  end

  private

  attr_reader :appointments

  def clusters
    result = []
    current = []
    current_end = nil

    appointments.each do |appointment|
      if current.empty? || appointment.starts_at < current_end
        current << appointment
        current_end = [ current_end, appointment.ends_at ].compact.max
      else
        result << current
        current = [ appointment ]
        current_end = appointment.ends_at
      end
    end
    result << current if current.any?
    result
  end

  def place_cluster(cluster)
    column_ends = []
    assignments = {}

    cluster.each do |appointment|
      column = column_ends.find_index { |end_time| end_time <= appointment.starts_at }
      if column
        column_ends[column] = appointment.ends_at
      else
        column_ends << appointment.ends_at
        column = column_ends.size - 1
      end
      assignments[appointment] = column
    end

    total_columns = column_ends.size
    cluster.map { |appointment| Placement.new(appointment: appointment, column: assignments[appointment], columns: total_columns) }
  end
end

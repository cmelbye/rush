# A rush box is a single unix machine - a server, workstation, or VPS instance.
#
# Specify a box by hostname (default = 'localhost').  If the box is remote, the
# first action performed will attempt to open an ssh tunnel.  Use square
# brackets to access the filesystem, or processes to access the process list.
#
# Example:
#
#   local = Rush::Box.new('localhost')
#   local['/etc/hosts'].contents
#   local.processes
#
class Rush::Box
	attr_reader :host

	# Instantiate a box.  No action is taken to make a connection until you try
	# to perform an action.  If the box is remote, an ssh tunnel will be opened.
	# Specify a username with the host if the remote ssh user is different from
	# the local one (e.g. Rush::Box.new('user@host')).
	def initialize(host='localhost')
		@host = host
	end

	def to_s        # :nodoc:
		host
	end

	def inspect     # :nodoc:
		host
	end

	# Access / on the box.
	def filesystem
		Rush::Entry.factory('/', self)
	end

	# Look up an entry on the filesystem, e.g. box['/path/to/some/file'].
	# Returns a subclass of Rush::Entry - either Rush::Dir if you specifiy
	# trailing slash, or Rush::File otherwise.
	def [](key)
		filesystem[key]
	end

	# Get the list of processes currently running on the box.  Returns an array
	# of Rush::Process.
	def processes
		connection.processes.map do |ps|
			Rush::Process.new(ps, self)
		end
	end

	# Execute a command in the standard unix shell.  Until the day when it's no
	# longer needed...
	def bash(command)
		connection.bash(command)
	end

	def connection         # :nodoc:
		@connection ||= make_connection
	end

	def make_connection    # :nodoc:
		host == 'localhost' ? Rush::Connection::Local.new : Rush::Connection::Remote.new(host)
	end

	def ==(other)          # :nodoc:
		host == other.host
	end
end
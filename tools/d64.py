#!/usr/bin/env python

import sys

# ugly hack for implementing class methods
class Callable:
	def __init__( self, method ):
		self.__call__ = method

class D64Sector( object ):
	def __init__( self, track = -1, sector = -1, data = None ):
		self.size = 256
		self.track = track
		self.sector = sector

		if not data:
			self.scratch()
		else:
			if len( data ) == self.size:
				self.data = data
			elif len( data ) < self.size:
				self.data = data
				self.data += [0] * ( self.size - len( data ) )
			else: #len( data ) > self.size:
				self.data = data[:self.size]

	def __getslice__( self, start, end ):
		return self.data[start:end]

	def __str__( self ):
		return " ".join( [ hex(x/16)[2]+hex(x%16)[2] for x in self.data ] )

	def size():
		return 256
	size = Callable( size )

	def scratch( self ):
		self.data = [0]*256

	def read( self ):
		return self.data


class D64DirectoryEntry( object ):
	def __init__( self, data = None ):
		if data:
			self.parse( data )
		else:
			self.parse( [0]*32 )

	def parse( self, data ):
		self.next_dir_sector = {
			'track': data[0],
			'sector': data[1]
		}
		self.file_type = data[2]
		self.first_sector = {
			'track': data[3],
			'sector': data[4]
		}
		self.filename = data[5:21]
		while self.filename[-1] == 0xa0:
			self.filename = self.filename[:-1]
		self.first_side_sector = {
			'track': data[21],
			'sector': data[22]
		}
		self.file_record_length = data[23]
		self.geos_data = data[24:30]
		self.file_size = data[30]+data[31]*256

	def file_type_str( self ):
		if self.file_type == 0x80:
			return "DEL"
		elif self.file_type == 0x81:
			return "SEQ"
		elif self.file_type == 0x82:
			return "PRG"
		else:
			return "$" + hex( self.file_type / 16 )[2:] + hex( self.file_type % 16 )[2:]

	def cbm_to_ascii( char, lowercase = False ):
		"""CBM to ASCII conversion as per http://www.c64-wiki.de/index.php/PETSCII"""
		if lowercase:
			return '................................ !"#$%&\'()*+,-./0123456789:;<=>?@abcdefghijklmnopqrstuvwxyz[.]^<-ABCDEFGHIJKLMNOPQRSTUVWXYZ+.|.\\................................ |_-_|.|./|...._....|||--_......-ABCDEFGHIJKLMNOPQRSTUVWXYZ+.|.\\ |_-_|.|./|...._....|||--_......'[char]
		else:
			return '................................ !"#$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[.]^<-.|---_||....\\/..._.|....|.+.|.\\................................ |_-_|.|./|...._....|||--_......-.|---_||....\\/..._.|....|.+.|.\\ |_-_|.|./|...._....|||--_......'[char]
		#VIC encoding:
		#return '@abcdefghijklmnopqrstuvwxyz[.]^< !"#$%&\'()*+,-./0123456789:;<=>?-ABCDEFGHIJKLMNOPQRSTUVWXYZ.....................................'[char%128]
		#return '@ABCDEFGHIJKLMNOPQRSTUVWXYZ[.]^< !"#$%&\'()*+,-./0123456789:;<=>?-...............................................................'[char%128]
	cbm_to_ascii = Callable( cbm_to_ascii )

	def cbm_to_ascii_str( string, lowercase = False ):
		return "".join( [ D64DirectoryEntry.cbm_to_ascii( x ) for x in string ] )
	cbm_to_ascii_str = Callable( cbm_to_ascii_str )


	def ascii_file_name( self, lowercase = False ):
		return "".join( [ D64DirectoryEntry.cbm_to_ascii( x, lowercase ) for x in self.filename ] )

	def is_empty( self ):
		return self.file_type == 0 and self.first_sector['track'] == 0

	def __str__( self ):
		line = ""
		line += str(self.file_size)
		line += " "*(5-len(line)) + '"' + self.ascii_file_name() + '"'
		line += " "*(16+7-len(line))
		line += " " + self.file_type_str()
		line += " (" + str(self.next_dir_sector['track'])
		line += "-"  + str(self.next_dir_sector['sector'])
		line += ","  + str(self.first_sector['track'])
		line += "-"  + str(self.first_sector['sector'])
		line += ")"
		return line

	def to_data( self ):
		return [
			self.next_dir_sector['track'],
			self.next_dir_sector['sector'],
			self.file_type,
			self.first_sector['track'],
			self.first_sector['sector']
		] + self.filename + [
			self.first_side_sector['track'],
			self.first_side_sector['sector'],
			self.file_record_length
		] + self.geos_data + [
			self.file_size % 256,
			self.file_size / 256
		]



class D64Directory( object ):
	def __init__( self, disk ):
		self.disk = disk
		self.entries = []
		next_dir_track = 18
		next_dir_sector = 1
		while next_dir_track >= 1 and next_dir_track <= 40:
			sector = disk.read_sector( next_dir_track, next_dir_sector )
			for nr in range( 0, 8 ):
				start_byte = nr*32
				end_byte = (nr+1)*32
				entry = D64DirectoryEntry( sector[start_byte:end_byte] )
				if nr == 0:
					next_dir_track = entry.next_dir_sector['track']
					next_dir_sector = entry.next_dir_sector['sector']
				if entry.is_empty():
					break
				else:
					self.entries.append( entry )

	def disk_title( self ):
		info = self.disk.read_sector( 18, 0 ).read()[144:167]
		title = info[:16]
		id = info[-5:]
		return ( title, id )

	def disk_title_str( self ):
		( title, id ) = self.disk_title()
		title = D64DirectoryEntry.cbm_to_ascii_str( title )
		id = D64DirectoryEntry.cbm_to_ascii_str( id )
		return ( title, id )

	def __str__( self ):
		( title, id ) = self.disk_title_str()
		dir = "0 \"" + title + "\" " + id + "\n"
		dir += "\n".join( [ str( x ) for x in self.entries ] )
		return dir		


class D64Track( object ):
	def __init__( self, nr, data = None ):
		self.nr = nr
		if data:
			self.data = data
		else:
			self.data = [0]*256*21
		start_sector = D64Track.sector_offset( nr )
		end_sector = D64Track.sector_offset( nr + 1 )
		sectors_in_track = end_sector - start_sector
		self.sectors = []
		for sector in range( 0, sectors_in_track ):
			start_byte = sector * D64Sector.size()
			end_byte = (sector+1) * D64Sector.size()
			self.sectors.append( D64Sector( nr, sector, data[start_byte:end_byte] ) )

	def __getitem__( self, nr ):
		return self.sectors[nr]

	def __setitem__( self, nr, sector ) :
		self.sectors[nr].set( sector )

	def sector_offsets():
		return [
			0,
			0, 21, 42, 63, 84, 105, 126, 147, 168, 189,
			210, 231, 252, 273, 294, 315, 336, 357, 376, 395,
			414, 433, 452, 471, 490, 508, 526, 544, 562, 580,
			598, 615, 632, 649, 666, 683, 700, 717, 734, 751,
			768
		]
	sector_offsets = Callable( sector_offsets )

	def sector_offset( nr = None ):
		if not nr:
			nr = self.nr
		return D64Track.sector_offsets()[nr]
	sector_offset = Callable( sector_offset )

	def sectors( nr = None ):
		if not nr:
			nr = self.nr
		return D64Track.sector_offsets()[nr+1] - D64Track.sector_offsets()[nr]
	sectors = Callable( sectors )


class D64Disk( object ):

	def __init__( self, filename = None ):
		try:
			with open( filename, "rb" ) as f:
				data = [ ord( x ) for x in  f.read() ]
		except:
			data = [0]*D64Sector.size()*768

		self.tracks = []
		for track in range(1,41):
			start_sector = D64Track.sector_offset( track )
			end_sector = D64Track.sector_offset( track + 1 )
			start_byte = start_sector * D64Sector.size()
			end_byte = end_sector * D64Sector.size()
			self.tracks.append(
			  D64Track( track, data[start_byte:end_byte] ) )
	
	def __getitem__( self, nr ):
		return self.tracks[nr-1]

	def __setitem__( self, nr, track ) :
		self.tracks[nr-1].set( track )

	def read_track( self, track ):
		return self.tracks[track-1]

	def read_sector( self, track, sector ):
		return self.read_track(track)[sector]

	def directory( self ):
		return D64Directory( self )

if __name__ == '__main__':
	d = D64Disk( sys.argv[1] )
	dir = d.directory()
	print dir

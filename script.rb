#!/usr/bin/env ruby

def fn_concat_init
  puts "fn_concat_init"
  @concat_pls = `mktemp -u -p . concat.XXXXXXXXXX.txt`.chomp
  @concat_pls.sub!("./", "")
  puts "concat_pls=#{@concat_pls}"
  `mkfifo "#{@concat_pls}"`
  puts
end

def fn_concat_feed(file)
  puts "fn_concat_feed #{file}"

  # Remove the existing FIFO file, if it exists
  if File.exist?(@concat_pls)
    puts "removing #{@concat_pls}"
    File.delete(@concat_pls)
  end

  # Reinitialize the FIFO file
  fn_concat_init

  # Write the required information to the FIFO
  File.open(@concat_pls, "w") do |fifo|
    fifo.puts "ffconcat version 1.0"
    fifo.puts "file '#{file}'"
    fifo.puts "file '#{@concat_pls}'"
  end

  puts "Content written to #{@concat_pls}"
end

def fn_concat_end
  puts "fn_concat_end"

  # Remove the FIFO file at the end
  if File.exist?(@concat_pls)
    puts "removing #{@concat_pls}"
    File.delete(@concat_pls)
  end

  puts
end

# Initialize
fn_concat_init

puts "launching ffmpeg ... all.mkv"
# Run ffmpeg in the background, similar to the Bash script
ffmpeg_process = IO.popen("timeout 60s ffmpeg -y -re -loglevel warning -i #{@concat_pls} -pix_fmt yuv422p all.mkv", "w")

# Capture the ffmpeg process ID
ffplay_pid = ffmpeg_process.pid

# Simulate generating test data and feeding it into the concat process
puts "generating some test data..."
i = 0
%w[red yellow green blue].each do |color|
  # Generate video for each color
  `ffmpeg -loglevel warning -y -f lavfi -i testsrc=s=720x576:r=12:d=4 -pix_fmt yuv422p -vf "drawbox=w=50:h=w:t=w:c=#{color}" test#{i}.mkv`

  # Feed the video to the concat process
  fn_concat_feed("test#{i}.mkv")
  i += 1
  puts
end
puts "done"

# End the concat process
fn_concat_end

# Wait for ffmpeg to finish encoding the final video
Process.wait(ffplay_pid)

puts "done encoding all.mkv"

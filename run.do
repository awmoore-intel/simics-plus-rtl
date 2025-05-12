set fd [dump -file inter.vpd]
dump -add . -depth 0 -fid $fd
dump -autoflush on -fid $fd
dump -interval 1 -fid $fd
run
dump -close
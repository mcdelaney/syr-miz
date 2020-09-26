
recs = {}
fp_ = open("C://Users/mcdel/Saved Games/DCS/Logs/syr-miz.log", 'r')
try:
    for line in fp_.readlines():
        try:
            val = line.strip().split("|")[-1]
            recs[val] += 1
        except KeyError:
            recs[val] = 1
except Exception:
   pass
i = 0
for k, v in recs.items():
    if v == 1:
        print(k)
        i+=1

print(i)

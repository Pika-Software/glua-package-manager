local Promise = gpm.Promise

print "Hello world from my package!"

Promise.delay(1):await()

return "this package is da best"

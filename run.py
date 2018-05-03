POPULATION_SIZE = 10
EVOLUTION_COUNT = 10

# Creates initial population
def createInitialPopulation(n):
    population = []
    for x in range(0, n):
        population.append(createRandomGenome())
    return population

# creates genome with random parameters within boundaries
# returns dict containing dict
def createRandomGenome():
    genome = {}
    # TODO
    # fill genome with key-value pairs consisting 
    # of parameter and value (within boundaries of that parameter)
    genomeFitness = getGenomeFitness(genome)
    testedGenome = {'genome': genome, 'fitness': genomeFitness}
    return testedGenome

def getGenomeFitness(genome):
    netLogoCommand = createNetLogoCommand(genome)
    fitness = testGenome()
    return fitness

def createNetLogoCommand(parameters):
    netLogoCommand = 'netlogo-headless.sh --model Model.nlogo '
    for parameter in parameters:
        netLogoCommand += '--%s %s ' % parameter, parameters[parameter]
    return netLogoCommand

def testGenome()
    # TODO run NetLogo command and get results somehow
    return fitness

# Program
population = createInitialPopulation(POPULATION_SIZE)


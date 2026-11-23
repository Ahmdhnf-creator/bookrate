import { PrismaPg } from '@prisma/adapter-pg'
import { PrismaClient } from '../../src/generated'

const DATABASE_URL = process.env.DATABASE_URL

if (!DATABASE_URL) {
  throw new Error('DATABASE_URL is not defined')
}

let prisma: PrismaClient

declare global {
  var __bookrate_prisma: PrismaClient | undefined
}

if (process.env.NODE_ENV === 'production') {
  const adapter = new PrismaPg({ connectionString: DATABASE_URL })
  prisma = new PrismaClient({ adapter })
} else {
  if (!global.__bookrate_prisma) {
    const adapter = new PrismaPg({ connectionString: DATABASE_URL })
    global.__bookrate_prisma = new PrismaClient({ adapter })
  }
  prisma = global.__bookrate_prisma
}

export { prisma }

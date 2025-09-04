import { prisma } from '@/lib/db'

/**
 * API route for tasks.
 *
 * GET: return all tasks ordered by dueDate ascending (nulls last).
 * POST: create a new task. Expects JSON body with at minimum title and entityType.
 */
export async function GET() {
  // Fetch tasks from database
  const tasks = await prisma.task.findMany({
    orderBy: [
      { dueDate: 'asc' },
      // createdAt is not defined on Task; tasks will return in default order for ties
    ],
  })
  return new Response(JSON.stringify(tasks), {
    headers: { 'Content-Type': 'application/json' },
  })
}

export async function POST(req: Request) {
  try {
    const body = await req.json()
    const { title, entityType, entityId, dueDate } = body || {}
    if (!title || !entityType) {
      return new Response(JSON.stringify({ error: 'Missing title or entityType' }), { status: 400 })
    }
    const created = await prisma.task.create({
      data: {
        title,
        entityType,
        entityId: entityId || '',
        dueDate: dueDate ? new Date(dueDate) : null,
        // assignedTo left null for now
        status: 'Open',
      },
    })
    return new Response(JSON.stringify(created), {
      status: 201,
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err: any) {
    console.error('Error creating task', err)
    return new Response(JSON.stringify({ error: 'Internal error' }), { status: 500 })
  }
}
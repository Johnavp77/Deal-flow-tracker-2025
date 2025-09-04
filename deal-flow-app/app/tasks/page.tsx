import { useEffect, useState } from 'react'

interface Task {
  id: string
  title: string
  entityType: string
  entityId: string
  dueDate: string | null
  status: string
}

// Simple Tasks page: fetch tasks from API and allow creation of a new task.
export default function TasksPage() {
  const [tasks, setTasks] = useState<Task[]>([])
  const [loading, setLoading] = useState(true)
  // form state
  const [newTask, setNewTask] = useState({
    title: '',
    entityType: '',
    entityId: '',
    dueDate: '',
  })
  const [showForm, setShowForm] = useState(false)

  useEffect(() => {
    async function loadTasks() {
      try {
        const res = await fetch('/api/tasks')
        if (res.ok) {
          const data = await res.json()
          setTasks(data)
        }
      } finally {
        setLoading(false)
      }
    }
    loadTasks()
  }, [])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    // Basic validation: require title and entity type
    if (!newTask.title || !newTask.entityType) return
    const res = await fetch('/api/tasks', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(newTask),
    })
    if (res.ok) {
      const created = await res.json()
      setTasks((prev) => [...prev, created])
      setNewTask({ title: '', entityType: '', entityId: '', dueDate: '' })
      setShowForm(false)
    }
  }

  return (
    <div className="page p-4">
      <div className="flex items-center justify-between mb-4">
        <h1 className="text-xl font-bold">Tasks</h1>
        <button
          className="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700"
          onClick={() => setShowForm(!showForm)}
        >
          {showForm ? 'Cancel' : '+ Add Task'}
        </button>
      </div>
      {showForm && (
        <form onSubmit={handleSubmit} className="mb-4 bg-gray-50 p-4 rounded border">
          <div className="grid md:grid-cols-4 gap-3">
            <div>
              <label className="block text-sm font-medium">Title</label>
              <input
                type="text"
                className="w-full border rounded p-2 text-sm"
                value={newTask.title}
                onChange={(e) => setNewTask({ ...newTask, title: e.target.value })}
                required
              />
            </div>
            <div>
              <label className="block text-sm font-medium">Entity Type</label>
              <select
                className="w-full border rounded p-2 text-sm"
                value={newTask.entityType}
                onChange={(e) => setNewTask({ ...newTask, entityType: e.target.value })}
                required
              >
                <option value="">Select</option>
                <option value="Deal">Deal</option>
                <option value="Property">Property</option>
                <option value="Availability">Availability</option>
                <option value="Tour">Tour</option>
                <option value="Shortlist">Shortlist</option>
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium">Entity ID</label>
              <input
                type="text"
                className="w-full border rounded p-2 text-sm"
                value={newTask.entityId}
                onChange={(e) => setNewTask({ ...newTask, entityId: e.target.value })}
              />
            </div>
            <div>
              <label className="block text-sm font-medium">Due Date</label>
              <input
                type="date"
                className="w-full border rounded p-2 text-sm"
                value={newTask.dueDate}
                onChange={(e) => setNewTask({ ...newTask, dueDate: e.target.value })}
              />
            </div>
          </div>
          <div className="mt-3">
            <button
              type="submit"
              className="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700"
            >
              Save Task
            </button>
          </div>
        </form>
      )}
      {loading ? (
        <div>Loading tasks...</div>
      ) : (
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Title
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Entity
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Due Date
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {tasks.map((task) => (
                <tr key={task.id}>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{task.title}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {task.entityType}{task.entityId && ` – ${task.entityId}`}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {task.dueDate ? new Date(task.dueDate).toLocaleDateString() : '-'}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{task.status}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
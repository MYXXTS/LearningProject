import axios from 'axios'

const api = axios.create({
  baseURL: '/api',
  timeout: 120000, // 2 min for training
})

api.interceptors.response.use(
  (res) => res.data,
  (err) => {
    const msg = err.response?.data?.detail || err.message || '请求失败'
    return Promise.reject(new Error(msg))
  }
)

// -------- Dataset --------
export const uploadDataset = (file) => {
  const form = new FormData()
  form.append('file', file)
  return api.post('/dataset/upload', form, {
    headers: { 'Content-Type': 'multipart/form-data' },
  })
}
export const listDatasets = () => api.get('/dataset/')
export const getDatasetEDA = (id) => api.get(`/dataset/${id}/eda`)

// -------- Train --------
export const startTraining = (payload) => api.post('/train/', payload)
export const listJobs = () => api.get('/train/jobs')
export const getJob = (id) => api.get(`/train/jobs/${id}`)

// -------- Predict --------
export const predictSingle = (payload) => api.post('/predict/single', payload)

export const predictBatch = (jobId, file) => {
  const form = new FormData()
  form.append('file', file)
  return axios.post(`/api/predict/batch?job_id=${jobId}`, form, {
    responseType: 'blob',
  })
}

export const getPredictionHistory = (limit = 50) =>
  api.get(`/predict/history?limit=${limit}`)

const express = require('express');
const app = express();
const PORT = process.env.PORT || ${{ values.port }};

app.get('/health', (req, res) => res.json({ status: 'ok', service: '${{ values.name }}' }));
app.get('/', (req, res) => res.json({ service: '${{ values.name }}', description: '${{ values.description }}' }));

app.listen(PORT, () => console.log(`${{ values.name }} running on port ${PORT}`));

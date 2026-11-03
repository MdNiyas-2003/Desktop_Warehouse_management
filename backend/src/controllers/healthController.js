const { query } = require('../db');

async function getHealth(_req, res) {
    try {
        await query('SELECT 1');
        return res.json({
            ok: true,
            message: 'API and database are healthy',
        });
    } catch (error) {
        return res.status(500).json({
            ok: false,
            message: error.message,
        });
    }
}

module.exports = { getHealth };

const { query } = require('../db');

async function getCategories(req, res) {
    const search = String(req.query.q || '').trim();
    try {
        const result = await query(
            `SELECT id, name, created_at
             FROM categories
             WHERE $1 = '' OR name ILIKE '%' || $1 || '%'
             ORDER BY name`,
            [search],
        );

        return res.json(result.rows);
    } catch (error) {
        return res.status(500).json({
            message: error.message,
        });
    }
}

async function createCategory(req, res) {
    const { name, description = '' } = req.body || {};

    if (!name || String(name).trim().length === 0) {
        return res.status(400).json({
            message: 'Category name is required',
        });
    }

    try {
        const exists = await query(
            `SELECT id FROM categories WHERE LOWER(name)=LOWER($1)`,
            [name.trim()],
        );

        if (exists.rowCount > 0) {
            return res.status(409).json({
                message: 'Category already exists',
            });
        }

        const result = await query(
            `INSERT INTO categories (name) VALUES($1)
RETURNING *`,
            [name.trim()],
        );

        return res.status(201).json(result.rows[0]);
    } catch (error) {
        return res.status(500).json({
            message: error.message,
        });
    }
}

async function deleteCategory(req, res) {
    const { id } = req.params;

    try {
        const result = await query(
            `DELETE FROM categories WHERE id=$1 RETURNING id`,
            [id],
        );

        if (result.rowCount === 0) {
            return res.status(404).json({
                message: 'Category not found',
            });
        }

        return res.json({
            message: 'Category deleted successfully',
        });
    } catch (error) {
        if (error.code === '23503') {
            return res.status(400).json({
                message: 'Category already used by items.',
            });
        }

        return res.status(500).json({
            message: error.message,
        });
    }
}

module.exports = {
    getCategories,
    createCategory,
    deleteCategory,
};

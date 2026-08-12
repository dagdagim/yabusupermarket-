const Sale = require('../models/Sale');
const Product = require('../models/Product');
const ExcelJS = require('exceljs');
const PDFDocument = require('pdfkit');
const { successResponse, errorResponse } = require('../utils/response');

const getDateRange = (period, startDate, endDate) => {
  const now = new Date();
  if (startDate && endDate) {
    return { start: new Date(startDate), end: new Date(new Date(endDate).setHours(23, 59, 59, 999)) };
  }
  if (period === 'daily') {
    const start = new Date(now); start.setDate(now.getDate() - 6); start.setHours(0, 0, 0, 0);
    const end = new Date(now); end.setHours(23, 59, 59, 999);
    return { start, end };
  }
  if (period === 'weekly') {
    const start = new Date(now); start.setDate(now.getDate() - 6); start.setHours(0, 0, 0, 0);
    return { start, end: now };
  }
  if (period === 'monthly') {
    const start = new Date(now.getFullYear(), now.getMonth(), 1);
    return { start, end: now };
  }
  // Default: last 30 days
  const start = new Date(now); start.setDate(now.getDate() - 29); start.setHours(0, 0, 0, 0);
  return { start, end: now };
};

// @desc    Generate report data
// @route   GET /api/reports
// @access  Admin
const getReport = async (req, res) => {
  try {
    const { period = 'daily', shop, startDate, endDate } = req.query;
    const { start, end } = getDateRange(period, startDate, endDate);

    const matchFilter = {
      createdAt: { $gte: start, $lte: end },
      status: 'completed',
    };
    if (shop) matchFilter.shop = new (require('mongoose').Types.ObjectId)(shop);

    const [salesSummary, topProducts, shopBreakdown, dailyTrendRaw] = await Promise.all([
      // Overall summary
      Sale.aggregate([
        { $match: matchFilter },
        {
          $group: {
            _id: null,
            totalRevenue: { $sum: '$totalAmount' },
            totalProfit: { $sum: '$totalProfit' },
            totalTransactions: { $sum: 1 },
            totalItemsSold: { $sum: { $sum: '$items.quantitySold' } },
            avgSaleValue: { $avg: '$totalAmount' },
          },
        },
      ]),

      // Top products
      Sale.aggregate([
        { $match: matchFilter },
        { $unwind: '$items' },
        {
          $group: {
            _id: '$items.product',
            productName: { $first: '$items.productName' },
            totalSold: { $sum: '$items.quantitySold' },
            totalRevenue: { $sum: '$items.totalPrice' },
            totalProfit: { $sum: '$items.profit' },
          },
        },
        { $sort: { totalSold: -1 } },
        { $limit: 10 },
      ]),

      // Per-shop breakdown
      Sale.aggregate([
        { $match: matchFilter },
        {
          $group: {
            _id: '$shop',
            shopName: { $first: '$shopName' },
            totalRevenue: { $sum: '$totalAmount' },
            totalProfit: { $sum: '$totalProfit' },
            totalTransactions: { $sum: 1 },
          },
        },
        { $sort: { totalRevenue: -1 } },
      ]),

      // Daily trend
      Sale.aggregate([
        { $match: matchFilter },
        {
          $group: {
            _id: {
              year: { $year: '$createdAt' },
              month: { $month: '$createdAt' },
              day: { $dayOfMonth: '$createdAt' },
            },
            revenue: { $sum: '$totalAmount' },
            profit: { $sum: '$totalProfit' },
            transactions: { $sum: 1 },
          },
        },
        { $sort: { '_id.year': 1, '_id.month': 1, '_id.day': 1 } },
      ]),
    ]);

    // Build continuous daily date map from start to end
    const dateMap = new Map();
    const cur = new Date(start);
    while (cur <= end) {
      const year = cur.getFullYear();
      const month = cur.getMonth() + 1;
      const day = cur.getDate();
      const key = `${year}-${month}-${day}`;
      dateMap.set(key, { _id: { year, month, day }, revenue: 0, profit: 0, transactions: 0 });
      cur.setDate(cur.getDate() + 1);
    }

    dailyTrendRaw.forEach((item) => {
      if (item._id && item._id.year) {
        const key = `${item._id.year}-${item._id.month}-${item._id.day}`;
        if (dateMap.has(key)) {
          dateMap.set(key, item);
        }
      }
    });

    const dailyTrend = Array.from(dateMap.values());

    return successResponse(
      res,
      {
        period,
        dateRange: { start, end },
        summary: salesSummary[0] || {
          totalRevenue: 0, totalProfit: 0, totalTransactions: 0, totalItemsSold: 0,
        },
        topProducts,
        shopBreakdown,
        dailyTrend,
      },
      'Report generated'
    );
  } catch (error) {
    return errorResponse(res, 'Failed to generate report.', 500);
  }
};

// @desc    Export report as Excel
// @route   GET /api/reports/export/excel
// @access  Admin
const exportExcel = async (req, res) => {
  try {
    const { period = 'daily', shop, startDate, endDate } = req.query;
    const { start, end } = getDateRange(period, startDate, endDate);

    const matchFilter = {
      createdAt: { $gte: start, $lte: end },
      status: 'completed',
    };
    if (shop) matchFilter.shop = new (require('mongoose').Types.ObjectId)(shop);

    const sales = await Sale.find(matchFilter)
      .populate('shop', 'name')
      .populate('shopkeeper', 'name')
      .sort({ createdAt: -1 });

    const workbook = new ExcelJS.Workbook();
    workbook.creator = 'Yabu Supermarket System';
    workbook.created = new Date();

    // Sales Sheet
    const sheet = workbook.addWorksheet('Sales Report');
    sheet.columns = [
      { header: 'Sale #', key: 'saleNumber', width: 20 },
      { header: 'Date', key: 'date', width: 20 },
      { header: 'Shop', key: 'shop', width: 20 },
      { header: 'Shopkeeper', key: 'shopkeeper', width: 20 },
      { header: 'Items', key: 'items', width: 10 },
      { header: 'Total (ETB)', key: 'total', width: 15 },
      { header: 'Profit (ETB)', key: 'profit', width: 15 },
      { header: 'Payment', key: 'payment', width: 15 },
    ];

    // Style header
    sheet.getRow(1).font = { bold: true, color: { argb: 'FFFFFFFF' } };
    sheet.getRow(1).fill = {
      type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF1E3A5F' },
    };

    sales.forEach((sale) => {
      sheet.addRow({
        saleNumber: sale.saleNumber,
        date: sale.createdAt.toLocaleString('en-ET'),
        shop: sale.shopName,
        shopkeeper: sale.shopkeeperName,
        items: sale.items.reduce((s, i) => s + i.quantitySold, 0),
        total: sale.totalAmount,
        profit: sale.totalProfit,
        payment: sale.paymentMethod,
      });
    });

    // Summary row
    const totals = sales.reduce(
      (acc, s) => ({ revenue: acc.revenue + s.totalAmount, profit: acc.profit + s.totalProfit }),
      { revenue: 0, profit: 0 }
    );

    const summaryRow = sheet.addRow({
      saleNumber: 'TOTAL',
      total: totals.revenue,
      profit: totals.profit,
    });
    summaryRow.font = { bold: true };
    summaryRow.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFFFE0B2' } };

    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', `attachment; filename=report-${period}-${Date.now()}.xlsx`);

    await workbook.xlsx.write(res);
    res.end();
  } catch (error) {
    return errorResponse(res, 'Failed to export Excel.', 500);
  }
};

// @desc    Export report as PDF
// @route   GET /api/reports/export/pdf
// @access  Admin
const exportPDF = async (req, res) => {
  try {
    const { period = 'daily', shop, startDate, endDate } = req.query;
    const { start, end } = getDateRange(period, startDate, endDate);

    const matchFilter = {
      createdAt: { $gte: start, $lte: end },
      status: 'completed',
    };

    const summary = await Sale.aggregate([
      { $match: matchFilter },
      {
        $group: {
          _id: '$shop',
          shopName: { $first: '$shopName' },
          totalRevenue: { $sum: '$totalAmount' },
          totalTransactions: { $sum: 1 },
        },
      },
    ]);

    const overall = summary.reduce(
      (acc, s) => ({ revenue: acc.revenue + s.totalRevenue, txns: acc.txns + s.totalTransactions }),
      { revenue: 0, txns: 0 }
    );

    const doc = new PDFDocument({ margin: 50 });
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename=report-${period}-${Date.now()}.pdf`);
    doc.pipe(res);

    // Header
    doc.fontSize(22).font('Helvetica-Bold').text('Yabu Supermarket Sales Report', { align: 'center' });
    doc.fontSize(12).font('Helvetica').text(`Period: ${period.toUpperCase()} | ${start.toDateString()} - ${end.toDateString()}`, { align: 'center' });
    doc.moveDown(1.5);

    // Summary
    doc.fontSize(16).font('Helvetica-Bold').text('Summary');
    doc.moveTo(50, doc.y).lineTo(550, doc.y).stroke();
    doc.moveDown(0.5);
    doc.fontSize(12).font('Helvetica');
    doc.text(`Total Revenue:  ${overall.revenue.toLocaleString()} ETB`);
    doc.text(`Total Transactions:  ${overall.txns}`);
    doc.moveDown(1);

    // Per-shop breakdown
    doc.fontSize(16).font('Helvetica-Bold').text('Shop Breakdown');
    doc.moveTo(50, doc.y).lineTo(550, doc.y).stroke();
    doc.moveDown(0.5);

    summary.forEach((s) => {
      doc.fontSize(12).font('Helvetica-Bold').text(s.shopName || 'Unknown Shop');
      doc.font('Helvetica').text(`  Revenue: ${s.totalRevenue.toLocaleString()} ETB`);
      doc.text(`  Transactions: ${s.totalTransactions}`);
      doc.moveDown(0.5);
    });

    doc.moveDown(2);
    doc.fontSize(10).fillColor('#888').text('Generated by Yabu Supermarket System', { align: 'center' });

    doc.end();
  } catch (error) {
    return errorResponse(res, 'Failed to export PDF.', 500);
  }
};

module.exports = { getReport, exportExcel, exportPDF };

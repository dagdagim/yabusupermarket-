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
    const { period = 'daily', shop, startDate, endDate, ekub = 0 } = req.query;
    const { start, end } = getDateRange(period, startDate, endDate);

    const matchFilter = {
      createdAt: { $gte: start, $lte: end },
      status: 'completed',
    };
    if (shop) matchFilter.shop = new (require('mongoose').Types.ObjectId)(shop);

    const [
      salesSummaryRaw,
      topProducts,
      shopBreakdown,
      dailyTrendRaw,
      paymentBreakdown,
      lowStockProducts,
      totalInventoryStats
    ] = await Promise.all([
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

      // Payment method breakdown
      Sale.aggregate([
        { $match: matchFilter },
        {
          $group: {
            _id: '$paymentMethod',
            totalRevenue: { $sum: '$totalAmount' },
            count: { $sum: 1 }
          }
        }
      ]),

      // Low stock products
      Product.find({ $expr: { $lte: ['$quantity', '$minQuantity'] } }).limit(10),

      // Inventory stats
      Product.aggregate([
        {
          $group: {
            _id: null,
            totalProducts: { $sum: 1 },
            totalStockValue: { $sum: { $multiply: ['$quantity', '$sellingPrice'] } }
          }
        }
      ])
    ]);

    const summary = salesSummaryRaw[0] || {
      totalRevenue: 0,
      totalProfit: 0,
      totalTransactions: 0,
      totalItemsSold: 0,
      avgSaleValue: 0,
    };

    const totalRevenue = summary.totalRevenue || 0;
    const totalProfit = summary.totalProfit || 0;
    const totalCost = Math.max(0, totalRevenue - totalProfit);
    const profitMargin = totalRevenue > 0 ? ((totalProfit / totalRevenue) * 100).toFixed(1) : '0.0';
    const ekubDeduction = parseFloat(ekub) || (totalProfit * 0.1);
    const remainingProfit = totalProfit - ekubDeduction;

    const doc = new PDFDocument({ margin: 40, size: 'A4', bufferPages: true });
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `inline; filename=Yabu-Supermarket-Full-Report-${Date.now()}.pdf`);
    doc.pipe(res);

    const formatETB = (val) => `${Number(val || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} ETB`;

    // HEADER
    doc.rect(40, 40, 515, 65).fill('#1E3A5F');
    doc.fillColor('#FFFFFF').fontSize(18).font('Helvetica-Bold').text('YABU SUPERMARKET', 55, 52);
    doc.fontSize(11).font('Helvetica').text('Comprehensive Executive Financial & Analytics Report', 55, 74);
    doc.fontSize(9).fillColor('#64B5F6').text('Created by Tobiya | Developed by Dagim Bekele (https://dagimbekelebunera.vercel.app/)', 55, 88);

    doc.moveDown(2);
    let y = 118;

    // Report Metadata Sub-header
    doc.fillColor('#333333').fontSize(9).font('Helvetica-Bold');
    doc.text(`Period: ${period.toUpperCase()}`, 40, y);
    doc.text(`Date Range: ${start.toLocaleDateString()} to ${end.toLocaleDateString()}`, 160, y);
    doc.text(`Generated: ${new Date().toLocaleString()}`, 370, y);

    y += 18;
    doc.moveTo(40, y).lineTo(555, y).strokeColor('#E0E0E0').strokeWidth(1).stroke();
    y += 12;

    // SECTION 1: KEY PERFORMANCE INDICATORS (KPIs)
    doc.fillColor('#1E3A5F').fontSize(13).font('Helvetica-Bold').text('1. Executive Financial Summary', 40, y);
    y += 20;

    const cardWidth = 120;
    const cardHeight = 50;
    const cards = [
      { label: 'TOTAL REVENUE', val: formatETB(totalRevenue), bg: '#E8F5E9', border: '#2E7D32', text: '#1B5E20' },
      { label: 'NET PROFIT', val: formatETB(totalProfit), bg: '#E3F2FD', border: '#1565C0', text: '#0D47A1' },
      { label: 'PROFIT MARGIN', val: `${profitMargin}%`, bg: '#FFF3E0', border: '#EF6C00', text: '#E65100' },
      { label: 'TRANSACTIONS', val: `${summary.totalTransactions}`, bg: '#F3E5F5', border: '#7B1FA2', text: '#4A148C' },
    ];

    cards.forEach((c, idx) => {
      const cx = 40 + idx * 130;
      doc.rect(cx, y, cardWidth, cardHeight).fillAndStroke(c.bg, c.border);
      doc.fillColor('#666666').fontSize(7).font('Helvetica-Bold').text(c.label, cx + 8, y + 8);
      doc.fillColor(c.text).fontSize(10).font('Helvetica-Bold').text(c.val, cx + 8, y + 26);
    });

    y += cardHeight + 18;

    // SECTION 2: PROFIT & EKUB SAVINGS CALCULATOR
    doc.fillColor('#1E3A5F').fontSize(13).font('Helvetica-Bold').text('2. Profit & Ekub Savings Analysis', 40, y);
    y += 18;

    doc.rect(40, y, 515, 52).fillAndStroke('#FAFAFA', '#D6D6D6');
    doc.fillColor('#333333').fontSize(9).font('Helvetica');
    doc.text(`Gross Revenue: ${formatETB(totalRevenue)}`, 52, y + 10);
    doc.text(`Total Product Cost: ${formatETB(totalCost)}`, 220, y + 10);
    doc.text(`Gross Profit: ${formatETB(totalProfit)}`, 400, y + 10);

    doc.font('Helvetica-Bold').fillColor('#E65100').text(`Ekub Contribution: -${formatETB(ekubDeduction)}`, 52, y + 30);
    doc.fillColor('#2E7D32').text(`Net Retained Profit: ${formatETB(remainingProfit)}`, 220, y + 30);

    y += 65;

    // SECTION 3: DAILY SALES & PROFIT TREND TABLE
    doc.fillColor('#1E3A5F').fontSize(13).font('Helvetica-Bold').text('3. Daily Sales & Profit Trend', 40, y);
    y += 18;

    // Table Header
    doc.rect(40, y, 515, 20).fill('#1E3A5F');
    doc.fillColor('#FFFFFF').fontSize(8).font('Helvetica-Bold');
    doc.text('Date', 45, y + 6);
    doc.text('Transactions', 140, y + 6);
    doc.text('Revenue (ETB)', 230, y + 6);
    doc.text('Net Profit (ETB)', 350, y + 6);
    doc.text('Margin %', 470, y + 6);

    y += 20;

    if (dailyTrendRaw.length === 0) {
      doc.rect(40, y, 515, 18).fill('#F9F9F9');
      doc.fillColor('#666666').fontSize(8).font('Helvetica').text('No daily trend data available for this range', 45, y + 5);
      y += 18;
    } else {
      dailyTrendRaw.forEach((row, idx) => {
        if (y > 720) {
          doc.addPage();
          y = 40;
        }
        const dateStr = row._id ? `${row._id.year}-${String(row._id.month).padStart(2,'0')}-${String(row._id.day).padStart(2,'0')}` : 'N/A';
        const rev = row.revenue || 0;
        const prof = row.profit || 0;
        const margin = rev > 0 ? ((prof / rev) * 100).toFixed(1) : '0.0';

        doc.rect(40, y, 515, 18).fill(idx % 2 === 0 ? '#F9F9F9' : '#FFFFFF');
        doc.fillColor('#333333').fontSize(8).font('Helvetica');
        doc.text(dateStr, 45, y + 5);
        doc.text(`${row.transactions || 0}`, 155, y + 5);
        doc.text(formatETB(rev), 230, y + 5);
        doc.text(formatETB(prof), 350, y + 5);
        doc.text(`${margin}%`, 475, y + 5);

        y += 18;
      });
    }

    y += 15;

    // SECTION 4: TOP SELLING PRODUCTS TABLE
    if (y > 650) { doc.addPage(); y = 40; }
    doc.fillColor('#1E3A5F').fontSize(13).font('Helvetica-Bold').text('4. Top Selling Products & Profitability', 40, y);
    y += 18;

    doc.rect(40, y, 515, 20).fill('#1E3A5F');
    doc.fillColor('#FFFFFF').fontSize(8).font('Helvetica-Bold');
    doc.text('#', 45, y + 6);
    doc.text('Product Name', 65, y + 6);
    doc.text('Units Sold', 250, y + 6);
    doc.text('Total Revenue (ETB)', 330, y + 6);
    doc.text('Total Profit (ETB)', 450, y + 6);

    y += 20;

    if (topProducts.length === 0) {
      doc.rect(40, y, 515, 18).fill('#F9F9F9');
      doc.fillColor('#666666').fontSize(8).font('Helvetica').text('No product sales recorded for this period', 45, y + 5);
      y += 18;
    } else {
      topProducts.forEach((p, idx) => {
        if (y > 720) { doc.addPage(); y = 40; }
        doc.rect(40, y, 515, 18).fill(idx % 2 === 0 ? '#F9F9F9' : '#FFFFFF');
        doc.fillColor('#333333').fontSize(8).font('Helvetica');
        doc.text(`${idx + 1}`, 45, y + 5);
        doc.text(p.productName || 'Unknown', 65, y + 5, { width: 175, lineBreak: false });
        doc.text(`${p.totalSold}`, 265, y + 5);
        doc.text(formatETB(p.totalRevenue), 330, y + 5);
        doc.text(formatETB(p.totalProfit), 450, y + 5);

        y += 18;
      });
    }

    y += 15;

    // SECTION 5: PAYMENT & SHOP BREAKDOWN
    if (y > 650) { doc.addPage(); y = 40; }
    doc.fillColor('#1E3A5F').fontSize(13).font('Helvetica-Bold').text('5. Payment Method & Shop Breakdown', 40, y);
    y += 18;

    doc.fontSize(9).font('Helvetica-Bold').fillColor('#333333').text('Payment Method Distribution:', 40, y);
    y += 14;
    if (paymentBreakdown.length === 0) {
      doc.fontSize(8).font('Helvetica').text('• No payment breakdown data available', 50, y);
      y += 14;
    } else {
      paymentBreakdown.forEach((pm) => {
        const methodLabel = pm._id === 'cash' ? 'Cash Payment' : 'Mobile Money / Transfer';
        doc.fontSize(8).font('Helvetica').text(`• ${methodLabel}: ${formatETB(pm.totalRevenue)} (${pm.count} transactions)`, 50, y);
        y += 14;
      });
    }

    y += 10;

    // SECTION 6: INVENTORY & LOW STOCK ALERTS
    if (y > 650) { doc.addPage(); y = 40; }
    doc.fillColor('#1E3A5F').fontSize(13).font('Helvetica-Bold').text('6. Low Stock & Inventory Warning', 40, y);
    y += 18;

    const invStats = totalInventoryStats[0] || { totalProducts: 0, totalStockValue: 0 };
    doc.fontSize(9).font('Helvetica').fillColor('#333333').text(`Total Active Products: ${invStats.totalProducts} | Total Stock Asset Value: ${formatETB(invStats.totalStockValue)}`, 40, y);
    y += 16;

    if (lowStockProducts.length === 0) {
      doc.fontSize(9).fillColor('#2E7D32').text('✔ All inventory stock levels are healthy.', 40, y);
      y += 16;
    } else {
      doc.rect(40, y, 515, 18).fill('#C62828');
      doc.fillColor('#FFFFFF').fontSize(8).font('Helvetica-Bold');
      doc.text('Product Name', 45, y + 5);
      doc.text('SKU / Code', 220, y + 5);
      doc.text('Current Quantity', 350, y + 5);
      doc.text('Min Requirement', 460, y + 5);
      y += 18;

      lowStockProducts.forEach((lp, idx) => {
        if (y > 720) { doc.addPage(); y = 40; }
        doc.rect(40, y, 515, 18).fill(idx % 2 === 0 ? '#FFEBEE' : '#FFFFFF');
        doc.fillColor('#B71C1C').fontSize(8).font('Helvetica');
        doc.text(lp.name, 45, y + 5, { width: 170, lineBreak: false });
        doc.text(lp.code || 'N/A', 220, y + 5);
        doc.text(`${lp.quantity}`, 370, y + 5);
        doc.text(`${lp.minQuantity}`, 480, y + 5);
        y += 18;
      });
    }

    // PAGE NUMBERS & FOOTER
    const range = doc.bufferedPageRange();
    for (let i = range.start; i < range.start + range.count; i++) {
      doc.switchToPage(i);
      doc.fontSize(8).fillColor('#888888').text(
        `Page ${i + 1} of ${range.count}  |  Yabu Supermarket System  |  Created by Tobiya (Dagim Bekele: https://dagimbekelebunera.vercel.app/)`,
        40,
        790,
        { align: 'center', width: 515 }
      );
    }

    doc.end();
  } catch (error) {
    logger.error('Export PDF error:', error);
    return errorResponse(res, 'Failed to export PDF.', 500);
  }
};

module.exports = { getReport, exportExcel, exportPDF };

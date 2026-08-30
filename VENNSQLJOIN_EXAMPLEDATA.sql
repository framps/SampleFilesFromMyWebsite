-- phpMyAdmin SQL Dump
-- version 3.4.5
-- http://www.phpmyadmin.net
--
-- Host: localhost
-- Generation Time: Nov 05, 2011 at 01:23 PM
-- Server version: 5.1.53
-- PHP Version: 5.3.5

SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;

--
-- Database: `VENNSQLJOINS`
--

CREATE DATABASE VENNSQLJOINs;

USE VENNSQLJOINS;

-- --------------------------------------------------------

--
-- Table structure for table `TableA`
--

CREATE TABLE IF NOT EXISTS `TableA` (
  `id` int(11) NOT NULL,
  `name` varchar(45) COLLATE utf8_unicode_ci NOT NULL,
  `nation` varchar(45) COLLATE utf8_unicode_ci NOT NULL,
  `table` char(1) COLLATE utf8_unicode_ci NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `TableA`
--

INSERT INTO `TableA` (`id`, `name`, `nation`, `table`) VALUES
(1, 'Albert', 'Germany', 'A'),
(2, 'Elizabeth', 'England', 'A'),
(3, 'Paul', 'Spain', 'A'),
(4, 'Julia', 'Denmark', 'A');

-- --------------------------------------------------------

--
-- Table structure for table `TableB`
--

CREATE TABLE IF NOT EXISTS `TableB` (
  `id` int(11) NOT NULL,
  `name` varchar(45) COLLATE utf8_unicode_ci NOT NULL,
  `nation` varchar(45) COLLATE utf8_unicode_ci NOT NULL,
  `table` char(1) COLLATE utf8_unicode_ci NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `TableB`
--

INSERT INTO `TableB` (`id`, `name`, `nation`, `table`) VALUES
(1, 'Marc', 'China', 'B'),
(2, 'Albert', 'France', 'B'),
(3, 'Peter', 'Japan', 'B'),
(4, 'Paul', 'Poland', 'B');

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
